locals {
  # Workspace name maps 1:1 to orgs/<name>/ directory.
  org_key = terraform.workspace

  # fileset(): path arg may traverse via ..; pattern arg may not.
  org_file_path = "${path.module}/../orgs/${local.org_key}/org.yaml"

  # Fallback YAML keeps `terraform validate` happy when workspace_guard would
  # otherwise block (e.g. CI running in 'default' workspace). Placeholder is
  # never reached at apply time — guard precondition refuses default workspace
  # and missing org.yaml before resources expand.
  org_raw = try(file(local.org_file_path), "orgId: \"validate-only-placeholder\"\n")
  org     = yamldecode(local.org_raw)

  project_files = fileset("${path.module}/..", "orgs/${local.org_key}/projects/*.yaml")

  projects = {
    for f in local.project_files :
    trimsuffix(basename(f), ".yaml") => yamldecode(file("${path.module}/../${f}"))
  }

  # ---------------------------------------------------------------------------
  # Template resolution
  # ---------------------------------------------------------------------------
  # Application teams pick a template from orgs/templates/<name>.yaml. Their
  # project YAML overrides specific fields. Merge rules:
  #   - scalar fields & top-level maps: project wins on overlap
  #   - clusters[]: merged by .name; project field wins per-cluster
  #   - users[]:   merged by .username; project field wins per-user
  #   - everything else (network, privateLink[], onlineArchive[], sqlFederation[]):
  #     if project declares the key, project replaces template entirely
  templates_dir = "${path.module}/../templates"

  templates = {
    for env_key, p in local.projects :
    env_key => try(yamldecode(file("${local.templates_dir}/${p.template}.yaml")), {})
    if try(p.template, null) != null
  }

  # Per-project: clusters merged by .name. Template clusters provide defaults;
  # project clusters with matching name override per field. Names only in
  # project are appended; names only in template are kept as-is.
  clusters_merged = {
    for env_key, p in local.projects :
    env_key => [
      for n in distinct(concat(
        [for c in lookup(p, "clusters", []) : c.name],
        [for c in lookup(lookup(local.templates, env_key, {}), "clusters", []) : c.name]
      )) :
      merge(
        lookup({ for c in lookup(lookup(local.templates, env_key, {}), "clusters", []) : c.name => c }, n, {}),
        lookup({ for c in lookup(p, "clusters", []) : c.name => c }, n, {})
      )
    ]
  }

  # Per-project: users grouped by access level (read_only / read_write) and
  # by auth type (scram / awsIamRoles). Group + subkey imply the Atlas role
  # and authType. Per-user `databases:` optional — absent = readAnyDatabase /
  # readWriteAnyDatabase on admin; present = per-db read / readWrite.
  # Subkeys are independently overridable: project's `read_only.scram` replaces
  # template's `read_only.scram` entirely; absent project subkeys fall back to
  # template's. SCRAM users still require an entry in var.user_passwords.
  users_merged = {
    for env_key, p in local.projects :
    env_key => concat(
      # read_only / SCRAM
      [
        for u in try(p.users.read_only.scram, lookup(local.templates, env_key, { users = { read_only = {} } }).users.read_only.scram, []) :
        {
          username   = u.username
          authType   = "SCRAM"
          awsIamType = null
          roles = lookup(u, "databases", null) != null ? [
            for db in u.databases : { role = "read", database = db }
            ] : [
            { role = "readAnyDatabase", database = "admin" }
          ]
        }
      ],
      # read_only / awsIamRoles
      [
        for u in try(p.users.read_only.awsIamRoles, lookup(local.templates, env_key, { users = { read_only = {} } }).users.read_only.awsIamRoles, []) :
        {
          username   = u.arn
          authType   = "AWS_IAM"
          awsIamType = "ROLE"
          roles = lookup(u, "databases", null) != null ? [
            for db in u.databases : { role = "read", database = db }
            ] : [
            { role = "readAnyDatabase", database = "admin" }
          ]
        }
      ],
      # read_write / SCRAM
      [
        for u in try(p.users.read_write.scram, lookup(local.templates, env_key, { users = { read_write = {} } }).users.read_write.scram, []) :
        {
          username   = u.username
          authType   = "SCRAM"
          awsIamType = null
          roles = lookup(u, "databases", null) != null ? [
            for db in u.databases : { role = "readWrite", database = db }
            ] : [
            { role = "readWriteAnyDatabase", database = "admin" }
          ]
        }
      ],
      # read_write / awsIamRoles
      [
        for u in try(p.users.read_write.awsIamRoles, lookup(local.templates, env_key, { users = { read_write = {} } }).users.read_write.awsIamRoles, []) :
        {
          username   = u.arn
          authType   = "AWS_IAM"
          awsIamType = "ROLE"
          roles = lookup(u, "databases", null) != null ? [
            for db in u.databases : { role = "readWrite", database = db }
            ] : [
            { role = "readWriteAnyDatabase", database = "admin" }
          ]
        }
      ]
    )
  }

  # Final per-project map after template merge. Downstream *_flat locals
  # operate on projects_resolved, not on raw projects.
  projects_resolved = {
    for env_key, p in local.projects :
    env_key => merge(
      lookup(local.templates, env_key, {}),
      p,
      { clusters = local.clusters_merged[env_key] },
      { users = local.users_merged[env_key] }
    )
  }

  # ---------------------------------------------------------------------------
  # Downstream flattening (consumes projects_resolved)
  # ---------------------------------------------------------------------------

  # Flatten clusters across all projects in this org for use with for_each.
  # Invariant: cluster names must be unique within (env, org).
  clusters_flat = merge([
    for env_key, p in local.projects_resolved : {
      for c in lookup(p, "clusters", []) :
      "${env_key}-${c.name}" => merge(c, { envKey = env_key })
    }
  ]...)

  users_flat = merge([
    for env_key, p in local.projects_resolved : {
      for u in lookup(p, "users", []) :
      "${env_key}-${u.username}" => merge(u, { envKey = env_key })
    }
  ]...)

  network_flat = merge([
    for env_key, p in local.projects_resolved : {
      for n in try(p.network.ipAccessList, []) :
      "${env_key}-${replace(n.cidr, "/", "_")}" => merge(n, { envKey = env_key })
    }
  ]...)

  # PrivateLink endpoints. Optional per-project.
  private_link_flat = merge([
    for env_key, p in local.projects_resolved : {
      for pl in lookup(p, "privateLink", []) :
      "${env_key}-${pl.region}" => merge(pl, { envKey = env_key })
    }
  ]...)

  # Online Archive rules. Optional per-project. Requires M10+ cluster.
  online_archive_flat = merge([
    for env_key, p in local.projects_resolved : {
      for oa in lookup(p, "onlineArchive", []) :
      "${env_key}-${oa.clusterName}-${oa.database}-${oa.collection}" => merge(oa, { envKey = env_key })
    }
  ]...)

  # Atlas SQL Interface via Data Federation. Optional per-project.
  sql_federation_flat = merge([
    for env_key, p in local.projects_resolved : {
      for fdi in lookup(p, "sqlFederation", []) :
      "${env_key}-${fdi.name}" => merge(fdi, { envKey = env_key })
    }
  ]...)
}
