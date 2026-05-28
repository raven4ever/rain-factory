# Atlas-side PrivateLink endpoint service. Always created when the project
# YAML declares privateLink entries. Customer creates the AWS VPC endpoint
# + security group out of band, then populates awsEndpointId in YAML.
resource "mongodbatlas_privatelink_endpoint" "this" {
  for_each = local.private_link_flat

  project_id    = mongodbatlas_project.this[each.value.envKey].id
  provider_name = each.value.providerName
  region        = each.value.region
}

# Binds the customer's AWS VPC endpoint ID back to the Atlas service.
# Conditional: only fires once YAML has awsEndpointId populated (second apply).
resource "mongodbatlas_privatelink_endpoint_service" "this" {
  for_each = {
    for k, v in local.private_link_flat : k => v
    if lookup(v, "awsEndpointId", "") != ""
  }

  project_id          = mongodbatlas_project.this[each.value.envKey].id
  private_link_id     = mongodbatlas_privatelink_endpoint.this[each.key].private_link_id
  provider_name       = each.value.providerName
  endpoint_service_id = each.value.awsEndpointId
}
