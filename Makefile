SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

CLUSTER_NAME ?= clac-demo
export CLUSTER_NAME

.PHONY: help doctor demo repair-gitops cluster argocd local-repo gitops-root ca wait status test test-platform test-issuance test-tls test-policy test-gitops test-renewal certificate-info watch-renewal argocd-ui argocd-password init-git destroy clean validate

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; printf "\nCertificate Lifecycle as Code\n\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

doctor: ## Check local prerequisites
	@./scripts/doctor.sh

demo: doctor cluster argocd local-repo gitops-root ca wait ## Build the complete local demo
	@./tests/platform.sh
	@./tests/issuance.sh
	@printf '\nCertificate Lifecycle Demo READY\n\n'

repair-gitops: local-repo gitops-root ca wait ## Rebuild the local Git bridge and reconcile Argo CD
	@printf '\nGitOps connection repaired\n\n'

cluster: ## Create the Kind cluster if it does not exist
	@./scripts/create-cluster.sh

argocd: ## Install the pinned Argo CD version
	@./scripts/bootstrap-argocd.sh

local-repo: ## Serve a local Git snapshot to Argo CD
	@./scripts/create-local-git.sh

gitops-root: ## Apply the Argo CD root Application
	@./scripts/apply-root-application.sh

ca: ## Generate the ephemeral lab CA outside Git
	@./scripts/bootstrap-ca.sh

wait: ## Wait until the platform and workload are ready
	@./scripts/wait-platform.sh

status: ## Show platform, Argo CD and certificate status
	@./scripts/status.sh

test: ## Run the fast integration suite (renewal excluded)
	@./tests/all.sh

test-platform: ## Verify controllers and issuer health
	@./tests/platform.sh

test-issuance: ## Verify X.509 issuance and key material
	@./tests/issuance.sh

test-tls: ## Verify the workload serves the issued certificate
	@./tests/tls.sh

test-policy: ## Prove a forbidden DNS request is denied
	@./tests/policy.sh

test-gitops: ## Prove Argo CD restores a deleted Certificate
	@./tests/gitops.sh

test-renewal: ## Wait for automatic renewal and key rotation (about 6 minutes)
	@./tests/renewal.sh

certificate-info: ## Inspect the current certificate and private-key hash
	@./scripts/certificate-info.sh

watch-renewal: ## Continuously show serial, key hash and renewal time
	@./scripts/verify-renewal.sh

argocd-ui: ## Port-forward the Argo CD UI to https://localhost:8080
	@kubectl -n argocd port-forward svc/argocd-server 8080:443

argocd-password: ## Print the initial Argo CD admin password
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; printf '\n'

init-git: ## Initialize this directory as a Git repository
	@./scripts/init-repository.sh

destroy: ## Delete the demo cluster and local runtime data
	@./scripts/destroy.sh

clean: destroy ## Alias for destroy

validate: ## Run offline syntax and repository checks
	@./scripts/validate.sh
