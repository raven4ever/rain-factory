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

output "privatelink" {
  description = "Per-region Atlas PrivateLink service info. Customer uses endpoint_service_name to create their AWS VPC endpoint, then pastes the resulting vpce-... back into the project YAML under awsEndpointId for a second apply."
  value = {
    for k, e in mongodbatlas_privatelink_endpoint.this : k => {
      endpoint_service_name = e.endpoint_service_name
      private_link_id       = e.private_link_id
      region                = e.region
    }
  }
}

output "online_archives" {
  description = "Map of online archive key (env-cluster-db-coll) to archive ID."
  value = {
    for k, a in mongodbatlas_online_archive.this : k => a.archive_id
  }
}

output "clusters" {
  description = "Map of cluster key to SRV connection string (null until cluster created)."
  value = {
    for k, c in mongodbatlas_advanced_cluster.this : k => try(c.connection_strings.standard_srv, null)
  }
}
