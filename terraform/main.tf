# Phases 1-4: workspace guard + project + cluster + users + network + federation.

# Workspace guard: refuse 'default' workspace and require matching orgs/<workspace>/org.yaml.
resource "terraform_data" "workspace_guard" {
  lifecycle {
    precondition {
      condition     = terraform.workspace != "default"
      error_message = "Refuse to run in 'default' workspace. Run: terraform workspace select <org-key>."
    }
    precondition {
      condition     = fileexists("${path.module}/../orgs/${terraform.workspace}/org.yaml")
      error_message = "Workspace '${terraform.workspace}' has no matching orgs/${terraform.workspace}/org.yaml."
    }
  }
}

resource "mongodbatlas_project" "this" {
  for_each = local.projects

  name   = each.value.name
  org_id = local.org.orgId
  tags   = lookup(local.org, "tags", {})
}

resource "mongodbatlas_advanced_cluster" "this" {
  for_each = local.clusters_flat

  project_id             = mongodbatlas_project.this[each.value.envKey].id
  name                   = each.value.name
  cluster_type           = lookup(each.value, "clusterType", "REPLICASET")
  mongo_db_major_version = each.value.mongoVersion
  backup_enabled         = each.value.backup
  tags                   = lookup(local.org, "tags", {})

  replication_specs = [{
    region_configs = [{
      provider_name = each.value.provider
      region_name   = each.value.region
      priority      = 7

      electable_specs = {
        instance_size = each.value.instanceSize
        node_count    = 3
        disk_size_gb  = each.value.diskSizeGB
      }
    }]
  }]
}

resource "mongodbatlas_database_user" "this" {
  for_each = local.users_flat

  project_id         = mongodbatlas_project.this[each.value.envKey].id
  username           = each.value.username
  auth_database_name = each.value.authType == "AWS_IAM" ? "$external" : "admin"
  password           = each.value.authType == "SCRAM" ? lookup(var.user_passwords, each.value.username, null) : null
  aws_iam_type       = each.value.authType == "AWS_IAM" ? lookup(each.value, "awsIamType", "USER") : null

  dynamic "roles" {
    for_each = each.value.roles
    content {
      role_name     = roles.value.role
      database_name = roles.value.database
    }
  }

  lifecycle {
    precondition {
      condition     = each.value.authType != "SCRAM" || lookup(var.user_passwords, each.value.username, null) != null
      error_message = "SCRAM user '${each.value.username}' has no entry in var.user_passwords. Set TF_VAR_user_passwords or add to terraform.tfvars."
    }
  }
}

resource "mongodbatlas_project_ip_access_list" "this" {
  for_each = local.network_flat

  project_id = mongodbatlas_project.this[each.value.envKey].id
  cidr_block = each.value.cidr
  comment    = lookup(each.value, "comment", null)
}

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
