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

1. Create a TFC workspace named after the org-key (e.g. `org1`). The CLI workspace name must match exactly — `local.org_key = terraform.workspace` drives `orgs/<name>/org.yaml` lookup.
2. Tag the workspace with `rain-factory` (matches the selector in `cloud.workspaces.tags`).
3. Set workspace variables (Variables tab → Terraform variable, mark sensitive):
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
