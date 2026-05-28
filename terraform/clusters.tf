# resource "mongodbatlas_advanced_cluster" "this" {
#   for_each = local.clusters_flat

#   project_id             = mongodbatlas_project.this[each.value.envKey].id
#   name                   = each.value.name
#   cluster_type           = lookup(each.value, "clusterType", "REPLICASET")
#   mongo_db_major_version = each.value.mongoVersion
#   backup_enabled         = each.value.backup
#   tags                   = lookup(local.org, "tags", {})

#   replication_specs = [{
#     region_configs = lookup(each.value, "regions", null) != null ? [
#       # Multi-region path: one region_config per regions[] entry.
#       # Priority rules (Atlas-enforced):
#       #   - exactly one region must have priority = 7 (preferred primary)
#       #   - priorities are integers 0..7 (0 = read-only/analytics only)
#       #   - sum of electableNodes across regions should be odd for quorum
#       for r in each.value.regions : merge(
#         {
#           provider_name = lookup(r, "provider", "AWS")
#           region_name   = r.region
#           priority      = r.priority
#         },
#         lookup(r, "electableNodes", 0) > 0 ? {
#           electable_specs = {
#             instance_size = lookup(r, "instanceSize", "M10")
#             node_count    = r.electableNodes
#             disk_size_gb  = each.value.diskSizeGB
#           }
#         } : {},
#         lookup(r, "readOnlyNodes", 0) > 0 ? {
#           read_only_specs = {
#             instance_size = lookup(r, "instanceSize", "M10")
#             node_count    = r.readOnlyNodes
#             disk_size_gb  = each.value.diskSizeGB
#           }
#         } : {},
#         lookup(r, "analyticsNodes", 0) > 0 ? {
#           analytics_specs = {
#             instance_size = lookup(r, "instanceSize", "M10")
#             node_count    = r.analyticsNodes
#             disk_size_gb  = each.value.diskSizeGB
#           }
#         } : {}
#       )
#       ] : [{
#         # Legacy single-region path: top-level region/provider/instanceSize.
#         provider_name = each.value.provider
#         region_name   = each.value.region
#         priority      = 7

#         electable_specs = {
#           instance_size = each.value.instanceSize
#           node_count    = 3
#           disk_size_gb  = each.value.diskSizeGB
#         }
#     }]
#   }]
# }
