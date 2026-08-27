# =============================================================================
# Odoo DevSecOps Lab — Operational Makefile
#
# This is the single entry point for the whole lab. It wires together:
#   Terraform  -> provisions Docker networks/volumes (and optional cloud infra)
#   Compose    -> runs the actual application stack (Odoo/Postgres/Nginx/monitoring)
#   Scripts    -> backup/restore, deploy (blue/green), security scans, chaos drills
#
# Usage:
#   make up ENV=dev
#   make plan ENV=staging
#   make deploy ENV=production COLOR=green
#
# ENV defaults to "dev" everywhere it matters, so `make up` alone boots a full
# local dev stack.
# =============================================================================

SHELL := /usr/bin/env bash
ENV ?= dev
PROJECT := odoo-lab
COMPOSE_DIR := compose
TF_DIR := terraform
ENV_FILE := envs/$(ENV).env

# Compose file layering: base infra + environment-specific overrides.
# Monitoring is opt-in via `make up-full` so a bare dev loop stays light.
COMPOSE_FILES := -f $(COMPOSE_DIR)/docker-compose.base.yml -f $(COMPOSE_DIR)/docker-compose.$(ENV).yml
COMPOSE := docker compose --env-file $(ENV_FILE) -p $(PROJECT)-$(ENV) $(COMPOSE_FILES)
COMPOSE_FULL := docker compose --env-file $(ENV_FILE) -p $(PROJECT)-$(ENV) $(COMPOSE_FILES) -f $(COMPOSE_DIR)/docker-compose.monitoring.yml

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "\033[36m%-28s\033[0m %s\n", $$1, $$2}'

# -----------------------------------------------------------------------------
# Infrastructure (Terraform) — networks, volumes, and optional cloud resources
# -----------------------------------------------------------------------------
.PHONY: tf-init tf-fmt tf-validate plan apply destroy
tf-init: ## terraform init for the given ENV
	cd $(TF_DIR) && terraform init -input=false

tf-fmt: ## terraform fmt -check (fails CI if not formatted)
	cd $(TF_DIR) && terraform fmt -check -recursive

tf-validate: tf-init ## terraform validate
	cd $(TF_DIR) && terraform validate

plan: tf-init ## terraform plan for ENV (dev|staging|production)
	cd $(TF_DIR) && terraform plan -var-file=environments/$(ENV).tfvars -out=$(ENV).tfplan

apply: ## terraform apply the previously generated plan (requires `make plan` first)
	cd $(TF_DIR) && terraform apply $(ENV).tfplan

destroy: ## terraform destroy for ENV — DESTRUCTIVE, asks for confirmation
	cd $(TF_DIR) && terraform destroy -var-file=environments/$(ENV).tfvars

# -----------------------------------------------------------------------------
# Application stack (Docker Compose)
# -----------------------------------------------------------------------------
.PHONY: up up-full down restart ps logs sh-odoo sh-db build
up: ## Start the app stack (odoo/nginx/postgres/pgbouncer) for ENV
	$(COMPOSE) up -d --remove-orphans

up-full: ## Start the app stack + full monitoring/observability stack
	$(COMPOSE_FULL) up -d --remove-orphans

down: ## Stop and remove containers for ENV (volumes are preserved)
	$(COMPOSE_FULL) down --remove-orphans

restart: down up ## Recreate the stack for ENV

ps: ## Show running containers for ENV
	$(COMPOSE_FULL) ps

logs: ## Tail logs for ENV (all services)
	$(COMPOSE_FULL) logs -f --tail=200

sh-odoo: ## Shell into the running Odoo container
	$(COMPOSE) exec odoo bash

sh-db: ## psql shell into Postgres
	$(COMPOSE) exec postgres psql -U $${POSTGRES_USER:-odoo} -d $${POSTGRES_DB:-odoo}

build: ## Build the custom Odoo/Nginx images for ENV
	$(COMPOSE) build --pull

# -----------------------------------------------------------------------------
# Deployment (build-once, promote strategy — see docs/adr/0004)
# -----------------------------------------------------------------------------
.PHONY: deploy rollback smoke-test promote
deploy: ## Blue/green deploy the currently tagged image to ENV
	./scripts/deploy/deploy.sh $(ENV)

rollback: ## Roll back ENV to the previous known-good color/tag
	./scripts/deploy/rollback.sh $(ENV)

smoke-test: ## Run post-deploy smoke tests against ENV
	./scripts/deploy/smoke_test.sh $(ENV)

promote: ## Promote the staging-validated image digest to production
	./scripts/deploy/promote_image.sh

# -----------------------------------------------------------------------------
# Backup / restore / disaster recovery
# -----------------------------------------------------------------------------
.PHONY: backup backup-filestore restore test-restore
backup: ## Run a full Postgres backup (restic) for ENV
	ENVIRONMENT=$(ENV) ./scripts/backup/backup_postgres.sh

backup-filestore: ## Run a filestore backup (restic) for ENV
	ENVIRONMENT=$(ENV) ./scripts/backup/backup_filestore.sh

restore: ## Restore Postgres from the latest snapshot for ENV — DESTRUCTIVE
	ENVIRONMENT=$(ENV) ./scripts/backup/restore_postgres.sh

test-restore: ## Restore into a throwaway container and validate integrity (safe, non-destructive)
	ENVIRONMENT=$(ENV) ./scripts/backup/test_restore.sh

# -----------------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------------
.PHONY: lint security-scan sbom sign verify-image
lint: ## Static checks: shellcheck, hadolint, tflint, yamllint
	./scripts/security/run_lint.sh

security-scan: ## gitleaks + semgrep + trivy (fs + config) + checkov
	./scripts/security/run_gitleaks.sh
	./scripts/security/run_trivy.sh fs .
	./scripts/security/run_trivy.sh config .

sbom: ## Generate SBOM (syft) for the Odoo image
	./scripts/security/generate_sbom.sh

sign: ## Cosign-sign the built image (keyless/OIDC in CI, key-based locally)
	./scripts/security/sign_image.sh

verify-image: ## Verify a cosign signature + SBOM attestation before deploy
	./scripts/security/verify_image.sh

# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------
.PHONY: test test-unit test-integration test-load
test: test-unit test-integration ## Run unit + integration tests

test-unit: ## Run custom Odoo addon unit tests inside the odoo container
	$(COMPOSE) run --rm odoo odoo -d $${POSTGRES_DB:-odoo_test} --test-enable --stop-after-init -i lab_demo_module

test-integration: ## Run black-box integration/smoke tests against a running ENV
	python3 tests/integration/test_health.py --base-url $${BASE_URL:-http://localhost}

test-load: ## Run the k6 load test against ENV
	k6 run tests/load/k6_load_test.js

# -----------------------------------------------------------------------------
# Chaos / DR drills
# -----------------------------------------------------------------------------
.PHONY: chaos-db chaos-odoo chaos-disk
chaos-db: ## Kill the Postgres container to rehearse the DR runbook
	./scripts/chaos/kill_postgres.sh $(ENV)

chaos-odoo: ## Kill the active-color Odoo container
	./scripts/chaos/kill_odoo.sh $(ENV)

chaos-disk: ## Simulate a near-full disk on the postgres volume
	./scripts/chaos/simulate_disk_full.sh $(ENV)
