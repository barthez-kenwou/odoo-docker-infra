package main

import future.keywords.in
import future.keywords.contains

# Run against `terraform show -json plan.tfplan > plan.json`.

deny contains msg if {
	some res in input.resource_changes
	res.type == "docker_network"
	res.change.after.name != null
	endswith(res.change.after.name, "-database")
	res.change.after.internal != true
	msg := sprintf("docker_network %q (the database tier) must have internal = true", [res.change.after.name])
}

deny contains msg if {
	some res in input.resource_changes
	res.type == "aws_s3_bucket_public_access_block"
	res.change.after.block_public_acls != true
	msg := "S3 backup bucket must block public ACLs (block_public_acls = true)"
}
