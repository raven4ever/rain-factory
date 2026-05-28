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

## Credentials

Source via env vars (preferred — keeps secrets off disk):

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
