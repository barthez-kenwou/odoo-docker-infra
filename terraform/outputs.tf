output "public_network_name"   { value = module.network.public_network_name }
output "private_network_name"  { value = module.network.private_network_name }
output "database_network_name" { value = module.network.database_network_name }

output "postgres_data_volume"        { value = module.volumes.postgres_data_name }
output "postgres_wal_archive_volume" { value = module.volumes.postgres_wal_archive_name }
output "odoo_filestore_volume"       { value = module.volumes.odoo_filestore_name }
output "backups_volume"              { value = module.volumes.backups_name }

output "server_ipv4" {
  value       = var.enable_cloud_compute ? module.compute[0].server_ipv4 : null
  description = "Only populated when enable_cloud_compute = true."
}

output "backup_bucket_name" {
  value       = var.enable_cloud_storage ? module.object_storage[0].bucket_name : null
  description = "Only populated when enable_cloud_storage = true."
}
