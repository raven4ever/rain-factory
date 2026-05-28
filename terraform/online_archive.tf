# Online Archive: tier-down cold data from a cluster collection based on a
# date field + TTL. Requires M10+ cluster. Cluster reference resolved via
# the flattened clusters_flat key envKey-clusterName.
resource "mongodbatlas_online_archive" "this" {
  for_each = local.online_archive_flat

  project_id   = mongodbatlas_project.this[each.value.envKey].id
  cluster_name = mongodbatlas_advanced_cluster.this["${each.value.envKey}-${each.value.clusterName}"].name
  db_name      = each.value.database
  coll_name    = each.value.collection

  criteria {
    type              = "DATE"
    date_field        = each.value.dateField
    date_format       = lookup(each.value, "dateFormat", "ISODATE")
    expire_after_days = each.value.expireAfterDays
  }

  dynamic "partition_fields" {
    for_each = lookup(each.value, "partitionFields", [])
    content {
      field_name = partition_fields.value.fieldName
      order      = partition_fields.value.order
    }
  }
}
