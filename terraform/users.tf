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
