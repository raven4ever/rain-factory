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
