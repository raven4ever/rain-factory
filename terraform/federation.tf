resource "mongodbatlas_federated_settings_org_role_mapping" "this" {
  for_each = try(local.org.federation.enabled, false) ? {
    for m in try(local.org.federation.roleMappings, []) : m.adGroup => m
  } : {}

  federation_settings_id = var.federation_settings_id
  org_id                 = local.org.orgId
  external_group_name    = each.value.adGroup

  role_assignments {
    org_id = local.org.orgId
    roles  = each.value.atlasRoles
  }
}
