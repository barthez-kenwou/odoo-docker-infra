output "public_network_name"   { value = docker_network.public.name }
output "private_network_name"  { value = docker_network.private.name }
output "database_network_name" { value = docker_network.database.name }
