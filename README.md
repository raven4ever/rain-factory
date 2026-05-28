# Rain Factory

GitOps control plane for MongoDB Atlas at enterprise scale. Atlas organizations, projects, clusters, users, network access, federation, PrivateLink endpoints, and SQL federation — declared in YAML, applied by Terraform Cloud on every push.

## Repo layout

```
rain-factory/
├── orgs/                    # Atlas org configurations (one dir per org)
│   └── <org-key>/
│       ├── org.yaml          # org-level: orgId, federation, tags
│       └── projects/
│           └── <env>.yaml    # one Atlas project per file
├── templates/               # shared project templates (small-dev, production-ha, ...)
├── terraform/               # single-root Terraform; per-feature HCL files
└── .github/
    ├── CODEOWNERS            # ownership rules
    └── workflows/
        └── terraform.yml     # fmt-check only (TFC owns plan/apply)
```

## Setup

First-time bootstrap is non-trivial: you need a Terraform Cloud account, an HCP Terraform / TFC organization, the `cloud.organization` value in `terraform/versions.tf` updated to match it, a TFC Project named `rain-factory` (renameable — see `cloud.workspaces.project`), a workspace per org, sensitive workspace variables (`atlas_public_key`, `atlas_private_key`, `federation_settings_id`, `user_passwords`), and a VCS connection wired from TFC to this GitHub repo.

All those steps live in [terraform/README.md](terraform/README.md#hcp-terraform--terraform-cloud). Follow it end-to-end before opening your first PR — there is no shorter path.

**Day-to-day usage after bootstrap:** push to `master` → TFC runs plan/apply automatically. Local `terraform plan` is optional (routes through TFC).

## Main functionalities

| Feature                  | What it does                                                        | Doc                                                                              |
| ------------------------ | ------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| YAML-driven projects     | Each `orgs/<org>/projects/*.yaml` becomes an Atlas project          | [terraform/README → Bootstrap](terraform/README.md#bootstrap)                    |
| Templates                | Inherit defaults from `templates/<name>.yaml`; override per field   | [→ Project Templates](terraform/README.md#project-templates)                     |
| Multi-region clusters    | Production HA via `regions[]` per cluster                           | [→ Multi-region clusters](terraform/README.md#multi-region-clusters)             |
| User access groups       | `read_only` / `read_write`, AWS IAM Roles + SCRAM                   | [→ Users](terraform/README.md#users)                                             |
| Network access list      | CIDR allowlist per project                                          | inline in project YAML                                                           |
| PrivateLink              | Atlas-side endpoint service; AWS-side stays in customer account     | [→ PrivateLink](terraform/README.md#privatelink)                                 |
| Online Archive           | Tier-down cold data based on date field + TTL                       | [→ Online Archive](terraform/README.md#online-archive)                           |
| Atlas SQL Interface      | JDBC/ODBC access via Data Federation                                | [→ Atlas SQL Interface](terraform/README.md#atlas-sql-interface-data-federation) |
| Federation role mappings | AD group → Atlas roles, driven by `org.yaml`                        | inline in `org.yaml`                                                             |
| Tags                     | Applied uniformly to Atlas projects + clusters from `org.yaml.tags` | inline                                                                           |

## Onboarding journey for a new app team

End-to-end timeline from "we need a MongoDB project" to "app is connected".

| Step | Who       | Action                                                                                                                                                                                           |
| ---- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1    | Platform  | Create `orgs/<org-key>/org.yaml` with `orgId`, `federation`, `tags`                                                                                                                              |
| 2    | Platform  | Create TFC workspace named `<org-key>` inside the `rain-factory` TFC Project; set sensitive workspace vars (`atlas_public_key`, `atlas_private_key`, `federation_settings_id`, `user_passwords`) |
| 3    | Platform  | Add CODEOWNERS entry: `/orgs/<org-key>/  @<org-key>-team`                                                                                                                                        |
| 4    | App team  | Pick a template from `templates/` (`small-dev` for sandbox, `production-ha` for prod)                                                                                                            |
| 5    | App team  | Create `orgs/<org-key>/projects/<env>.yaml` declaring `template:` + overrides + user groups                                                                                                      |
| 6    | App team  | Open PR                                                                                                                                                                                          |
| 7    | GitHub    | Auto-requests reviewers per CODEOWNERS                                                                                                                                                           |
| 8    | TFC       | Speculative plan runs via VCS webhook; result posted to PR                                                                                                                                       |
| 9    | Reviewers | Approve PR                                                                                                                                                                                       |
| 10   | App team  | Merge to `master` — TFC runs `terraform apply`                                                                                                                                                   |
| 11   | App team  | Connect to provisioned cluster via Atlas-generated SRV string + AWS IAM role                                                                                                                     |

Typical wall-clock: hours, not days. No tickets, no humans on the apply path.

## Responsibilities & ownership

| Path           | Owner               | Why                                          |
| -------------- | ------------------- | -------------------------------------------- |
| `/terraform/`  | Platform team       | Shared infra code; changes affect all orgs   |
| `/templates/`  | Platform            | Templates set defaults all consumers inherit |
| `/.github/`    | Platform team       | CI, workflows, branch policy                 |
| `/orgs/<org>/` | That org's app team | Project-specific config they live with daily |
| Anything else  | Platform team       | Catch-all default                            |

### Enforcement via CODEOWNERS

[.github/CODEOWNERS](.github/CODEOWNERS) encodes the table above. On PR open, GitHub:

1. Auto-requests review from matching owners per changed path
2. Posts a Code Owners status check

### Adding a new org

1. Edit `.github/CODEOWNERS` — add `/orgs/<new-org>/  @<new-org>-team`
2. Create `orgs/<new-org>/org.yaml` + `orgs/<new-org>/projects/`
3. Platform creates TFC workspace `<new-org>` in the rain-factory project
4. New app team follows the onboarding journey above

## Operational model

- **TFC is authoritative for state, plan, apply.** Connected to this repo via VCS integration. Speculative plans run on PRs; apply runs on push-to-`master` (manual confirm by default). The TFC organization name lives in `terraform/versions.tf` (`cloud.organization`) — currently `raven4ever` for this POC; change it to fit your own HCP Terraform / Terraform Cloud organization.
- **GitHub Actions runs only `terraform fmt -check`.** TFC validates and plans natively — duplicating it in CI would just waste minutes.
- **No local state.** `versions.tf` declares `cloud {}` block; CLI commands route through TFC.
- **Atlas API credentials live in TFC workspace variables**, not in GitHub secrets, not on disk.

## Where to look next

- [terraform/README.md](terraform/README.md) — feature-by-feature documentation and YAML schemas
- [templates/](templates/) — available templates (`small-dev.yaml`, `production-ha.yaml`)
- [orgs/org1/projects/dev.yaml](orgs/org1/projects/dev.yaml) — reference project with comments
