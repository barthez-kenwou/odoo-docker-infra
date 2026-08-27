output "postgres_data_name"        { value = docker_volume.postgres_data.name }
output "postgres_wal_archive_name" { value = docker_volume.postgres_wal_archive.name }
output "odoo_filestore_name"       { value = docker_volume.odoo_filestore.name }
output "backups_name"              { value = docker_volume.backups.name }
