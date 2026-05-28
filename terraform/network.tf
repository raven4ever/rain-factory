resource "mongodbatlas_project_ip_access_list" "this" {
  for_each = local.network_flat

  project_id = mongodbatlas_project.this[each.value.envKey].id
  cidr_block = each.value.cidr
  comment    = lookup(each.value, "comment", null)
}
