# Makefile dla Django na AWS z Terraform + Kubernetes

# Zmienne
PROJECT_NAME := django-app
ENVIRONMENT := dev
AWS_REGION := eu-east-1
DOCKER_REGISTRY := your-account.dkr.ecr.$(AWS_REGION).amazonaws.com
IMAGE_TAG := latest

# Kolory dla outputu
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m

.PHONY: help
help: ## Wyświetl dostępne komendy
	@echo "$(GREEN)Django na AWS - Terraform + Kubernetes$(NC)"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

# ==============================================================================
# Development
# ==============================================================================

.PHONY: setup
setup: ## Początkowa konfiguracja środowiska
	@echo "$(GREEN)Konfiguracja środowiska...$(NC)"
	@./scripts/setup.sh

.PHONY: build
build: ## Zbuduj obraz Docker aplikacji
	@echo "$(GREEN)Budowanie obrazu Docker...$(NC)"
	docker build -t $(PROJECT_NAME):$(IMAGE_TAG) .
	docker tag $(PROJECT_NAME):$(IMAGE_TAG) $(DOCKER_REGISTRY)/$(PROJECT_NAME):$(IMAGE_TAG)

.PHONY: push
push: build ## Wypchnij obraz do ECR
	@echo "$(GREEN)Pushowanie obrazu do ECR...$(NC)"
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(DOCKER_REGISTRY)
	docker push $(DOCKER_REGISTRY)/$(PROJECT_NAME):$(IMAGE_TAG)

.PHONY: test
test: ## Uruchom testy aplikacji
	@echo "$(GREEN)Uruchamianie testów...$(NC)"
	docker run --rm $(PROJECT_NAME):$(IMAGE_TAG) python manage.py test

.PHONY: lint
lint: ## Sprawdź kod (linting)
	@echo "$(GREEN)Sprawdzanie kodu...$(NC)"
	pre-commit run --all-files

# ==============================================================================
# Infrastructure
# ==============================================================================

.PHONY: tf-init
tf-init: ## Inicjalizuj Terraform
	@echo "$(GREEN)Inicjalizacja Terraform...$(NC)"
	cd deployment/terraform && terraform init

.PHONY: tf-plan
tf-plan: ## Zaplanuj zmiany infrastruktury
	@echo "$(GREEN)Planowanie zmian Terraform...$(NC)"
	cd deployment/terraform && terraform plan

.PHONY: tf-apply
tf-apply: ## Zastosuj zmiany infrastruktury
	@echo "$(GREEN)Aplikowanie zmian Terraform...$(NC)"
	cd deployment/terraform && terraform apply

.PHONY: tf-destroy
tf-destroy: ## Usuń całą infrastrukturę
	@echo "$(RED)UWAGA: To usunie całą infrastrukturę!$(NC)"
	@read -p "Czy na pewno chcesz kontynuować? [y/N]: " confirm && [ "$$confirm" = "y" ]
	cd deployment/terraform && terraform destroy

# ==============================================================================
# Kubernetes
# ==============================================================================

.PHONY: k8s-config
k8s-config: ## Skonfiguruj kubectl dla EKS
	@echo "$(GREEN)Konfiguracja kubectl...$(NC)"
	./scripts/update-kubeconfig.sh

.PHONY: k8s-deploy
k8s-deploy: ## Deploy aplikacji na Kubernetes
	@echo "$(GREEN)Deploying aplikacji na Kubernetes...$(NC)"
	cd deployment/kubernetes && kubectl apply -f base/

.PHONY: k8s-delete
k8s-delete: ## Usuń aplikację z Kubernetes
	@echo "$(YELLOW)Usuwanie aplikacji z Kubernetes...$(NC)"
	cd deployment/kubernetes && kubectl delete -f base/ --ignore-not-found=true

.PHONY: k8s-status
k8s-status: ## Sprawdź status aplikacji na Kubernetes
	@echo "$(GREEN)Status aplikacji:$(NC)"
	kubectl get pods,svc,ingress -l app=$(PROJECT_NAME)

.PHONY: k8s-logs
k8s-logs: ## Wyświetl logi aplikacji
	@echo "$(GREEN)Logi aplikacji:$(NC)"
	kubectl logs -l app=$(PROJECT_NAME) --tail=100 -f

# ==============================================================================
# Database
# ==============================================================================

.PHONY: db-migrate
db-migrate: ## Uruchom migracje bazy danych
	@echo "$(GREEN)Uruchamianie migracji...$(NC)"
	kubectl apply -f deployment/kubernetes/base/django-migration-job.yaml
	kubectl wait --for=condition=complete job/django-migrate --timeout=300s

.PHONY: db-shell
db-shell: ## Połącz się z bazą danych
	@echo "$(GREEN)Łączenie z bazą danych...$(NC)"
	kubectl run postgres-client --rm -ti --image=postgres:14 -- bash

# ==============================================================================
# Monitoring
# ==============================================================================

.PHONY: logs-app
logs-app: ## Wyświetl logi aplikacji
	kubectl logs -l app=$(PROJECT_NAME) --tail=50

.PHONY: logs-ingress
logs-ingress: ## Wyświetl logi ingress controller
	kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50

.PHONY: describe-pods
describe-pods: ## Opisz pody aplikacji
	kubectl describe pods -l app=$(PROJECT_NAME)

.PHONY: top
top: ## Wyświetl zużycie zasobów
	kubectl top nodes
	kubectl top pods

# ==============================================================================
# Utility
# ==============================================================================

.PHONY: clean
clean: ## Wyczyść lokalne obrazy Docker
	@echo "$(GREEN)Czyszczenie lokalnych obrazów...$(NC)"
	docker system prune -f
	docker image prune -f

.PHONY: get-url
get-url: ## Pobierz URL aplikacji
	@echo "$(GREEN)URL aplikacji:$(NC)"
	@LOAD_BALANCER_URL=$$(kubectl get ingress django-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
	if [ -n "$$LOAD_BALANCER_URL" ]; then \
		echo "http://$$LOAD_BALANCER_URL"; \
	else \
		echo "Load Balancer URL nie jest jeszcze dostępny. Spróbuj ponownie za chwilę."; \
	fi

.PHONY: port-forward
port-forward: ## Przekieruj port aplikacji lokalnie
	@echo "$(GREEN)Przekierowanie portu na localhost:8080...$(NC)"
	kubectl port-forward service/django-app-service 8080:80

# ==============================================================================
# Complete Workflows
# ==============================================================================

.PHONY: deploy-all
deploy-all: build push tf-apply k8s-config k8s-deploy ## Pełny deployment (infrastruktura + aplikacja)
	@echo "$(GREEN)Pełny deployment zakończony!$(NC)"
	@$(MAKE) get-url

.PHONY: destroy-all
destroy-all: k8s-delete tf-destroy ## Usuń wszystko
	@echo "$(RED)Wszystkie zasoby zostały usunięte$(NC)"

.PHONY: redeploy
redeploy: build push ## Ponowny deployment tylko aplikacji
	@echo "$(GREEN)Ponowny deployment aplikacji...$(NC)"
	kubectl rollout restart deployment/django-app
	kubectl rollout status deployment/django-app

.PHONY: scale-up
scale-up: ## Zwiększ liczbę replik do 4
	@echo "$(GREEN)Zwiększanie liczby replik...$(NC)"
	kubectl scale deployment/django-app --replicas=4

.PHONY: scale-down
scale-down: ## Zmniejsz liczbę replik do 2
	@echo "$(GREEN)Zmniejszanie liczby replik...$(NC)"
	kubectl scale deployment/django-app --replicas=2

# ==============================================================================
# Development helpers
# ==============================================================================

.PHONY: dev-setup
dev-setup: ## Konfiguracja środowiska deweloperskiego
	@echo "$(GREEN)Konfiguracja środowiska deweloperskiego...$(NC)"
	pip install pre-commit
	pre-commit install
	@echo "$(GREEN)Środowisko deweloperskie skonfigurowane!$(NC)"

.PHONY: check-tools
check-tools: ## Sprawdź czy wszystkie narzędzia są zainstalowane
	@echo "$(GREEN)Sprawdzanie narzędzi...$(NC)"
	@command -v terraform >/dev/null 2>&1 || (echo "$(RED)terraform nie jest zainstalowany$(NC)" && exit 1)
	@command -v kubectl >/dev/null 2>&1 || (echo "$(RED)kubectl nie jest zainstalowany$(NC)" && exit 1)
	@command -v aws >/dev/null 2>&1 || (echo "$(RED)aws cli nie jest zainstalowany$(NC)" && exit 1)
	@command -v docker >/dev/null 2>&1 || (echo "$(RED)docker nie jest zainstalowany$(NC)" && exit 1)
	@command -v helm >/dev/null 2>&1 || (echo "$(RED)helm nie jest zainstalowany$(NC)" && exit 1)
	@echo "$(GREEN)Wszystkie narzędzia są dostępne!$(NC)"

# Default target
.DEFAULT_GOAL := help