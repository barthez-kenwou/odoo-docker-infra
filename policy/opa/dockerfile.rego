package main

import future.keywords.in
import future.keywords.contains

# Expects Dockerfiles parsed by conftest's built-in Docker parser, which
# yields a flat list of {Cmd, Value} instructions.

last_user(instructions) := user if {
	users := [v | some i in instructions; i.Cmd == "user"; v := i.Value[0]]
	count(users) > 0
	user := users[count(users) - 1]
}

deny contains msg if {
	user := last_user(input)
	lower(user) == "root"
	msg := "final USER in the Dockerfile must not be root"
}

deny contains msg if {
	not last_user(input)
	msg := "Dockerfile never sets a non-root USER"
}

deny contains msg if {
	some i in input
	i.Cmd == "env"
	some kv in i.Value
	contains_secret_like_key(kv)
	msg := sprintf("suspicious secret-like ENV key baked into the image: %q", [kv])
}

contains_secret_like_key(kv) if {
	lower_kv := lower(kv)
	some pattern in ["password", "secret", "api_key", "token"]
	contains(lower_kv, pattern)
}
