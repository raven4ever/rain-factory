output "org_key" {
  description = "Active workspace / org key driving this state."
  value       = local.org_key
}

output "projects" {
  description = "Map of env-key to Atlas project ID."
  value = {
    for k, p in mongodbatlas_project.this : k => p.id
  }
}

output "debug_project_files" {
  description = "Temp diagnostic: paths returned by fileset() for the active workspace. Remove once verified."
  value       = local.project_files
}

output "clusters" {
  description = "Map of cluster key to SRV connection string (null until cluster created)."
  value = {
    for k, c in mongodbatlas_advanced_cluster.this : k => try(c.connection_strings.standard_srv, null)
  }
}
