package main

import future.keywords.in
import future.keywords.contains

services := input.services

# --- No floating tags on anything we build or pull ---
deny contains msg if {
	some name, svc in services
	svc.image
	endswith(svc.image, ":latest")
	msg := sprintf("service %q uses a ':latest' image tag — pin an explicit version", [name])
}

# --- Every service must drop all Linux capabilities and add back only what
#     it explicitly needs (see docker-compose.base.yml for the pattern) ---
deny contains msg if {
	some name, svc in services
	not svc.cap_drop
	msg := sprintf("service %q does not set cap_drop — must drop ALL and re-add only what's needed", [name])
}

deny contains msg if {
	some name, svc in services
	svc.cap_drop
	not "ALL" in svc.cap_drop
	msg := sprintf("service %q sets cap_drop but does not drop ALL", [name])
}

# --- Every service must declare a memory limit ---
deny contains msg if {
	some name, svc in services
	not svc.deploy.resources.limits.memory
	msg := sprintf("service %q has no deploy.resources.limits.memory set", [name])
}

# --- no-new-privileges must be set ---
deny contains msg if {
	some name, svc in services
	not "no-new-privileges:true" in svc.security_opt
	msg := sprintf("service %q is missing security_opt: no-new-privileges:true", [name])
}
