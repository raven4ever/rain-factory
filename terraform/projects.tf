resource "mongodbatlas_project" "this" {
  for_each = local.projects

  name   = each.value.name
  org_id = local.org.orgId
  tags   = lookup(local.org, "tags", {})
}
