# Atlas SQL Interface: Federated Database Instance per project that exposes
# Atlas data over JDBC/ODBC. Storage stores reference existing Atlas clusters;
# storage databases define the SQL schema mapping logical names to actual
# Atlas db/collection pairs.
resource "mongodbatlas_federated_database_instance" "this" {
  for_each = local.sql_federation_flat

  project_id = mongodbatlas_project.this[each.value.envKey].id
  name       = each.value.name

  dynamic "storage_databases" {
    for_each = lookup(each.value, "databases", [])
    content {
      name = storage_databases.value.name

      dynamic "collections" {
        for_each = storage_databases.value.collections
        content {
          name = collections.value.name

          dynamic "data_sources" {
            for_each = collections.value.dataSources
            content {
              store_name = data_sources.value.storeName
              database   = data_sources.value.database
              collection = data_sources.value.collection
            }
          }
        }
      }
    }
  }

  dynamic "storage_stores" {
    for_each = lookup(each.value, "stores", [])
    content {
      name         = storage_stores.value.name
      provider     = "atlas"
      cluster_name = mongodbatlas_advanced_cluster.this["${each.value.envKey}-${storage_stores.value.clusterName}"].name
      project_id   = mongodbatlas_project.this[each.value.envKey].id
    }
  }
}
