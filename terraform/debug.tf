output "debug_templates" {
  value = local.templates
}

output "debug_template_path" {
  value = "${local.templates_dir}/small-dev.yaml"
}

output "debug_template_exists" {
  value = fileexists("${local.templates_dir}/small-dev.yaml")
}

output "debug_projects_resolved" {
  value = local.projects_resolved
}
