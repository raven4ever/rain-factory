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

  # Flatten clusters across all projects in this org for use with for_each.
  # Invariant: cluster names must be unique within (env, org).
  clusters_flat = merge([
    for env_key, p in local.projects : {
      for c in lookup(p, "clusters", []) :
      "${env_key}-${c.name}" => merge(c, { envKey = env_key })
    }
  ]...)

  users_flat = merge([
    for env_key, p in local.projects : {
      for u in lookup(p, "users", []) :
      "${env_key}-${u.username}" => merge(u, { envKey = env_key })
    }
  ]...)

  network_flat = merge([
    for env_key, p in local.projects : {
      for n in try(p.network.ipAccessList, []) :
      "${env_key}-${replace(n.cidr, "/", "_")}" => merge(n, { envKey = env_key })
    }
  ]...)

  # PrivateLink endpoints. Optional per-project. Each entry creates an
  # Atlas-side endpoint service; the customer-owned AWS VPC endpoint + SG
  # are created out-of-band. Set awsEndpointId on the second apply to bind.
  private_link_flat = merge([
    for env_key, p in local.projects : {
      for pl in lookup(p, "privateLink", []) :
      "${env_key}-${pl.region}" => merge(pl, { envKey = env_key })
    }
  ]...)

  # Online Archive rules. Optional per-project. Each entry archives a
  # collection's cold data based on a date field + TTL. Requires M10+ cluster.
  # Cluster reference resolved by clusterName matching clusters[].name in the
  # same project YAML; flattening key includes db+coll for uniqueness.
  online_archive_flat = merge([
    for env_key, p in local.projects : {
      for oa in lookup(p, "onlineArchive", []) :
      "${env_key}-${oa.clusterName}-${oa.database}-${oa.collection}" => merge(oa, { envKey = env_key })
    }
  ]...)
}
