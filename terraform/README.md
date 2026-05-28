# Rain Factory Terraform

Single-root Terraform managing MongoDB Atlas orgs declared in `../orgs/`. State partitioned per org via Terraform workspaces.

## Prerequisites

- Terraform >= 1.6
- MongoDB Atlas programmatic API key with Org Owner (or equivalent) scope
- One directory under `../orgs/<org-key>/` with populated `org.yaml`

## Bootstrap

```bash
cd terraform/
terraform init

# One workspace per org. Name MUST match the orgs/<name>/ directory.
terraform workspace new org1
```

## HCP Terraform / Terraform Cloud

This root is wired to TFC (`versions.tf` → `cloud` block, organization `wrtv23`). State and runs are managed by TFC.

### One-time setup per org

1. Create a TFC Project named **`rain-factory`** (Settings → Projects → New project).
2. Create a workspace inside that Project, named after the org-key (e.g. `org1`). The CLI workspace name must match exactly — `local.org_key = terraform.workspace` drives `orgs/<name>/org.yaml` lookup.
3. Add the workspace tag **`app = rain-factory`** (Workspace → Settings → Tags). Matches the selector in `cloud.workspaces.tags`.
4. Set workspace variables (Variables tab → Terraform variable, mark sensitive):
   - `atlas_public_key`
   - `atlas_private_key`
   - `federation_settings_id`
   - `user_passwords` (HCL syntax, e.g. `{ "app-dev" = "..." }`)
4. (CI only) Generate a user API token in TFC user settings. Save it as GitHub secret `TF_API_TOKEN`.

### Local CLI auth

```bash
terraform login   # one-time, opens browser, stores token in ~/.terraform.d/credentials.tfrc.json
```

After login, `terraform init` + `terraform workspace select org1` + `terraform plan` runs against TFC.

## Credentials (local fallback)

Only needed if not using TFC workspace variables:

```bash
export TF_VAR_atlas_public_key=...
export TF_VAR_atlas_private_key=...
```

Or copy `terraform.tfvars.example` to `terraform.tfvars` (gitignored).

## Plan / Apply

```bash
terraform workspace select org1
terraform plan -out=tfplan
terraform apply tfplan
```

## PrivateLink

Each project YAML may declare an optional `privateLink` list. Each entry creates an Atlas-side PrivateLink endpoint service per region. Customer-owned AWS resources (VPC endpoint, security group) are intentionally **out of scope** — this Terraform root only manages Atlas.

### YAML

```yaml
privateLink:
  - region: US_EAST_1            # Atlas region
    providerName: AWS
    awsEndpointId: ""             # empty on first apply; "vpce-..." on second
```

### Two-phase apply

**Phase 1 — create Atlas service.** Leave `awsEndpointId: ""`. Apply.
```bash
terraform apply
terraform output privatelink
```
Output contains `endpoint_service_name` per region. Example:
```
com.amazonaws.vpce.us-east-1.vpce-svc-0abc1234...
```

**Phase 2 — customer creates AWS-side resources.** In the customer AWS account (any IaC or AWS Console):
1. Create a security group: ingress from your allowed CIDRs on TCP 1024–65535, egress open
2. Create an Interface VPC Endpoint targeting the Atlas `endpoint_service_name`, attached to your subnets and the SG
3. Note the resulting `vpce-...` endpoint ID

**Phase 3 — bind the AWS endpoint to Atlas.** Paste the `vpce-...` ID into the project YAML under `awsEndpointId`. Apply again — terraform creates the binding via `mongodbatlas_privatelink_endpoint_service`.

### Removing PrivateLink

Remove the `privateLink` entry from YAML and apply. Atlas-side service is destroyed. Customer must separately delete their AWS VPC endpoint and SG.

## Online Archive

Each project YAML may declare an optional `onlineArchive` list. Each entry creates a `mongodbatlas_online_archive` rule that tiers cold data from a cluster collection to cheaper storage based on a date field + TTL.

**Requirements:**
- Cluster instance size **M10 or higher** (Atlas restriction; M0/M2/M5 not supported)
- Online Archive is a **paid Atlas feature** — billed per archived GB

**YAML:**

```yaml
onlineArchive:
  - clusterName: primary           # must match clusters[].name in this file
    database: app
    collection: events
    dateField: createdAt
    dateFormat: ISODATE             # or EPOCH_SECONDS (optional)
    expireAfterDays: 90
    partitionFields:                # optional, improves query performance on archive
      - fieldName: tenantId
        order: 0
      - fieldName: createdAt
        order: 1
```

**Outputs:**

```bash
terraform output online_archives
# { "dev-primary-app-events" = "<archive-id>" }
```

Remove the YAML entry and apply to delete an archive rule. Archived data restoration is Atlas-side (out of Terraform).

## Atlas SQL Interface (Data Federation)

Each project YAML may declare an optional `sqlFederation` list. Each entry creates a `mongodbatlas_federated_database_instance` (FDI) — a SQL-queryable virtual database that maps Atlas cluster collections to logical SQL schemas. Clients connect using the **Atlas SQL JDBC/ODBC driver** (not the standard MongoDB driver).

**Requirements:**
- Paid Atlas feature — billed per federation query volume + data transfer
- Underlying Atlas clusters must already exist (referenced by `stores[].clusterName`)
- Client tooling: Atlas SQL JDBC, Atlas SQL ODBC, Tableau Connector, or Power BI Connector

**YAML:**

```yaml
sqlFederation:
  - name: dev-fdi
    stores:
      - name: primary-store          # logical name referenced by dataSources
        clusterName: primary          # must match clusters[].name in this file
    databases:
      - name: sql_app                 # logical SQL schema name
        collections:
          - name: events              # logical SQL "table" name
            dataSources:
              - storeName: primary-store
                database: app         # actual Atlas db name
                collection: events    # actual Atlas collection name
```

**Outputs:**

```bash
terraform output sql_federation
# { "dev-dev-fdi" = { name = "dev-fdi", hostnames = [ "atlas-sql-...mongodb.net" ] } }
```

Point Atlas SQL JDBC driver at the returned hostname.

Remove the YAML entry and apply to delete the FDI.

## Workspace Guard

Root refuses to run in `default` workspace and refuses if `../orgs/<workspace>/org.yaml` is missing. Create a workspace whose name matches the org directory.

## Phase Status

| Phase | Scope | Status |
|---|---|---|
| 1 | Project resource + workspace guard + YAML discovery | DONE |
| 2 | `mongodbatlas_advanced_cluster` | DONE |
| 3 | DB users + IP access list | DONE |
| 4 | Federation role mappings | DONE |
| 5 | Remote state (S3 + DynamoDB) + CI | DONE (CI scaffolded; S3 backend remains commented until bucket provisioned) |
