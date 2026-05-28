# Workspace guard. Refuses to run in 'default' workspace and refuses if the
# corresponding orgs/<workspace>/org.yaml is missing. Each feature's resources
# live in its own file: projects.tf, clusters.tf, users.tf, network.tf,
# federation.tf, privatelink.tf, online_archive.tf, sql_federation.tf.
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
