# Teable Helm Chart Makefile
# Common operations for managing Teable deployment

.PHONY: help install uninstall upgrade status logs shell test lint template dependencies clean dev prod staging

# Default values
NAMESPACE ?= teable
RELEASE_NAME ?= teable
CHART_PATH ?= ./teable-helm
VALUES_FILE ?=
ENVIRONMENT ?= development

# Colors for output
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
BLUE := \033[34m
RESET := \033[0m

help: ## Display this help message
	@echo "$(BLUE)Teable Helm Chart Management$(RESET)"
	@echo "================================"
	@echo ""
	@echo "$(GREEN)Available targets:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Environment Variables:$(RESET)"
	@echo "  NAMESPACE=$(NAMESPACE)"
	@echo "  RELEASE_NAME=$(RELEASE_NAME)"
	@echo "  CHART_PATH=$(CHART_PATH)"
	@echo "  ENVIRONMENT=$(ENVIRONMENT)"
	@echo ""
	@echo "$(GREEN)Examples:$(RESET)"
	@echo "  make install                    # Install with defaults"
	@echo "  make install NAMESPACE=prod     # Install in 'prod' namespace"
	@echo "  make prod                       # Install production environment"
	@echo "  make upgrade VALUES_FILE=my.yaml # Upgrade with custom values"

install: dependencies ## Install Teable with Helm
	@echo "$(GREEN)Installing Teable...$(RESET)"
	@if [ "$(VALUES_FILE)" != "" ]; then \
		helm install $(RELEASE_NAME) $(CHART_PATH) \
			--namespace $(NAMESPACE) \
			--create-namespace \
			--values $(VALUES_FILE); \
	else \
		helm install $(RELEASE_NAME) $(CHART_PATH) \
			--namespace $(NAMESPACE) \
			--create-namespace; \
	fi
	@echo "$(GREEN)Installation completed!$(RESET)"
	@$(MAKE) status

uninstall: ## Uninstall Teable
	@echo "$(RED)Uninstalling Teable...$(RESET)"
	@helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE) || true
	@echo "$(YELLOW)To completely clean up, run: kubectl delete namespace $(NAMESPACE)$(RESET)"

upgrade: dependencies ## Upgrade existing Teable installation
	@echo "$(GREEN)Upgrading Teable...$(RESET)"
	@if [ "$(VALUES_FILE)" != "" ]; then \
		helm upgrade $(RELEASE_NAME) $(CHART_PATH) \
			--namespace $(NAMESPACE) \
			--values $(VALUES_FILE); \
	else \
		helm upgrade $(RELEASE_NAME) $(CHART_PATH) \
			--namespace $(NAMESPACE); \
	fi
	@echo "$(GREEN)Upgrade completed!$(RESET)"

status: ## Show deployment status
	@echo "$(BLUE)Deployment Status:$(RESET)"
	@helm status $(RELEASE_NAME) --namespace $(NAMESPACE) || echo "$(RED)Release not found$(RESET)"
	@echo ""
	@echo "$(BLUE)Pods:$(RESET)"
	@kubectl get pods --namespace $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME) || true
	@echo ""
	@echo "$(BLUE)Services:$(RESET)"
	@kubectl get svc --namespace $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME) || true

logs: ## Show application logs
	@echo "$(BLUE)Teable Application Logs:$(RESET)"
	@kubectl logs --namespace $(NAMESPACE) -l app.kubernetes.io/name=teable -f --tail=100

logs-init: ## Show database migration logs
	@echo "$(BLUE)Database Migration Logs:$(RESET)"
	@kubectl logs --namespace $(NAMESPACE) -l app.kubernetes.io/name=teable -c db-migrate --tail=100

shell: ## Get shell access to Teable pod
	@echo "$(BLUE)Connecting to Teable pod...$(RESET)"
	@kubectl exec -it --namespace $(NAMESPACE) deployment/$(RELEASE_NAME) -- /bin/sh

test: ## Test the deployment
	@echo "$(BLUE)Testing Teable deployment...$(RESET)"
	@echo "Checking if pods are ready..."
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=teable --namespace $(NAMESPACE) --timeout=300s
	@echo "Testing health endpoint..."
	@kubectl exec --namespace $(NAMESPACE) deployment/$(RELEASE_NAME) -- curl -f http://localhost:3000/health
	@echo "$(GREEN)All tests passed!$(RESET)"

port-forward: ## Forward local port to Teable service
	@echo "$(BLUE)Port forwarding to Teable (http://localhost:8080)...$(RESET)"
	@kubectl port-forward --namespace $(NAMESPACE) svc/$(RELEASE_NAME) 8080:3000

port-forward-minio: ## Forward local port to MinIO console
	@echo "$(BLUE)Port forwarding to MinIO console (http://localhost:9001)...$(RESET)"
	@kubectl port-forward --namespace $(NAMESPACE) svc/$(RELEASE_NAME)-minio 9001:9001

lint: ## Lint the Helm chart
	@echo "$(BLUE)Linting Helm chart...$(RESET)"
	@helm lint $(CHART_PATH)
	@echo "$(GREEN)Lint completed!$(RESET)"

template: ## Generate Kubernetes manifests
	@echo "$(BLUE)Generating Kubernetes manifests...$(RESET)"
	@if [ "$(VALUES_FILE)" != "" ]; then \
		helm template $(RELEASE_NAME) $(CHART_PATH) \
			--namespace $(NAMESPACE) \
			--values $(VALUES_FILE); \
	else \
		helm template $(RELEASE_NAME) $(CHART_PATH) \
			--namespace $(NAMESPACE); \
	fi

dependencies: ## Update Helm dependencies
	@echo "$(BLUE)Updating Helm dependencies...$(RESET)"
	@helm dependency update $(CHART_PATH)

clean: ## Clean up generated files
	@echo "$(BLUE)Cleaning up...$(RESET)"
	@rm -rf $(CHART_PATH)/charts/*.tgz
	@rm -f $(CHART_PATH)/Chart.lock

dev: dependencies ## Install for development environment
	@echo "$(GREEN)Installing Teable for development...$(RESET)"
	@$(MAKE) install NAMESPACE=teable-dev RELEASE_NAME=teable-dev

staging: dependencies ## Install for staging environment
	@echo "$(GREEN)Installing Teable for staging...$(RESET)"
	@if [ -f "$(CHART_PATH)/values-staging.yaml" ]; then \
		$(MAKE) install NAMESPACE=teable-staging RELEASE_NAME=teable-staging VALUES_FILE=$(CHART_PATH)/values-staging.yaml; \
	else \
		echo "$(YELLOW)No staging values file found, using defaults$(RESET)"; \
		$(MAKE) install NAMESPACE=teable-staging RELEASE_NAME=teable-staging; \
	fi

prod: dependencies ## Install for production environment
	@echo "$(GREEN)Installing Teable for production...$(RESET)"
	@if [ -f "$(CHART_PATH)/values-prod.yaml" ]; then \
		$(MAKE) install NAMESPACE=teable-prod RELEASE_NAME=teable-prod VALUES_FILE=$(CHART_PATH)/values-prod.yaml; \
	else \
		echo "$(RED)Production values file not found: $(CHART_PATH)/values-prod.yaml$(RESET)"; \
		echo "$(YELLOW)Please create production values file first$(RESET)"; \
		exit 1; \
	fi

backup-db: ## Backup PostgreSQL database
	@echo "$(BLUE)Creating database backup...$(RESET)"
	@kubectl exec --namespace $(NAMESPACE) -it deployment/$(RELEASE_NAME)-postgresql -- pg_dump -U postgres teable > backup-$(shell date +%Y%m%d-%H%M%S).sql
	@echo "$(GREEN)Database backup completed!$(RESET)"

restore-db: ## Restore PostgreSQL database (requires BACKUP_FILE variable)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "$(RED)Please specify BACKUP_FILE variable$(RESET)"; \
		echo "Usage: make restore-db BACKUP_FILE=backup-20231201-120000.sql"; \
		exit 1; \
	fi
	@echo "$(BLUE)Restoring database from $(BACKUP_FILE)...$(RESET)"
	@kubectl exec --namespace $(NAMESPACE) -i deployment/$(RELEASE_NAME)-postgresql -- psql -U postgres -d teable < $(BACKUP_FILE)
	@echo "$(GREEN)Database restore completed!$(RESET)"

debug: ## Show debug information
	@echo "$(BLUE)Debug Information:$(RESET)"
	@echo ""
	@echo "$(YELLOW)Helm Releases:$(RESET)"
	@helm list --namespace $(NAMESPACE) || true
	@echo ""
	@echo "$(YELLOW)Pod Details:$(RESET)"
	@kubectl describe pods --namespace $(NAMESPACE) -l app.kubernetes.io/name=teable || true
	@echo ""
	@echo "$(YELLOW)ConfigMap:$(RESET)"
	@kubectl describe configmap --namespace $(NAMESPACE) $(RELEASE_NAME)-config || true
	@echo ""
	@echo "$(YELLOW)Secret:$(RESET)"
	@kubectl describe secret --namespace $(NAMESPACE) $(RELEASE_NAME)-secret || true
	@echo ""
	@echo "$(YELLOW)Events:$(RESET)"
	@kubectl get events --namespace $(NAMESPACE) --sort-by='.lastTimestamp' || true

check-prerequisites: ## Check if all prerequisites are installed
	@echo "$(BLUE)Checking prerequisites...$(RESET)"
	@command -v kubectl >/dev/null 2>&1 || { echo "$(RED)kubectl not found$(RESET)"; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "$(RED)helm not found$(RESET)"; exit 1; }
	@kubectl cluster-info >/dev/null 2>&1 || { echo "$(RED)Cannot connect to Kubernetes cluster$(RESET)"; exit 1; }
	@echo "$(GREEN)All prerequisites satisfied!$(RESET)"

watch: ## Watch pod status in real-time
	@echo "$(BLUE)Watching pods in namespace $(NAMESPACE)...$(RESET)"
	@kubectl get pods --namespace $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME) -w

# Shorthand aliases
i: install ## Alias for install
u: uninstall ## Alias for uninstall
s: status ## Alias for status
l: logs ## Alias for logs
t: test ## Alias for test

# Make help the default target
.DEFAULT_GOAL := help
