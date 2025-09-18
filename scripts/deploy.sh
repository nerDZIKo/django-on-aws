#!/bin/bash
# scripts/deploy.sh

set -e

# Kolory dla outputu
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funkcje pomocnicze
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Sprawdzenie wymaganych narzędzi
check_tools() {
    log_info "Sprawdzanie wymaganych narzędzi..."
    
    tools=("terraform" "kubectl" "aws" "helm")
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool nie jest zainstalowany"
            exit 1
        fi
    done
    
    log_info "Wszystkie narzędzia są dostępne"
}

# Sprawdzenie konfiguracji AWS
check_aws_config() {
    log_info "Sprawdzanie konfiguracji AWS..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "Nie można połączyć się z AWS. Sprawdź aws configure"
        exit 1
    fi
    
    log_info "Konfiguracja AWS jest poprawna"
}

# Deploy infrastruktury
deploy_infrastructure() {
    log_info "Deploying infrastruktury..."
    
    cd deployment/terraform
    
    # Sprawdzenie czy terraform.tfvars istnieje
    if [[ ! -f terraform.tfvars ]]; then
        log_error "Plik terraform.tfvars nie istnieje. Skopiuj z terraform.tfvars.example"
        exit 1
    fi
    
    # Inicjalizacja Terraform
    terraform init
    
    # Plan
    terraform plan -out=tfplan
    
    # Pytanie o kontynuację
    echo
    read -p "Czy chcesz kontynuować deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Deployment anulowany"
        exit 0
    fi
    
    # Apply
    terraform apply tfplan
    
    log_info "Infrastruktura została wdrożona"
    cd ../..
}

# Konfiguracja kubectl
configure_kubectl() {
    log_info "Konfiguracja kubectl..."
    
    # Pobierz nazwę klastra z Terraform output
    cd deployment/terraform
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    REGION=$(terraform output -raw region)
    cd ../..
    
    # Aktualizacja kubeconfig
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    # Sprawdzenie połączenia
    if kubectl get nodes &> /dev/null; then
        log_info "kubectl jest skonfigurowany poprawnie"
        kubectl get nodes
    else
        log_error "Nie można połączyć się z klastrem EKS"
        exit 1
    fi
}

# Deploy aplikacji
deploy_application() {
    log_info "Deploying aplikacji na Kubernetes..."
    
    cd deployment/kubernetes
    
    # Najpierw zastosuj ConfigMaps i Secrets
    log_info "Aplikowanie ConfigMaps i Secrets..."
    kubectl apply -f base/django-configmap.yaml
    kubectl apply -f base/django-secrets.yaml
    
    # Migracje bazy danych
    log_info "Uruchamianie migracji bazy danych..."
    kubectl apply -f base/django-migration-job.yaml
    kubectl wait --for=condition=complete job/django-migrate --timeout=300s
    
    # Collectstatic
    log_info "Zbieranie plików statycznych..."
    kubectl apply -f base/django-collectstatic-job.yaml
    kubectl wait --for=condition=complete job/django-collectstatic --timeout=300s
    
    # Deploy głównej aplikacji
    log_info "Deploying aplikacji Django..."
    kubectl apply -f base/django-deployment.yaml
    kubectl apply -f base/django-service.yaml
    
    # Ingress
    log_info "Konfiguracja Ingress..."
    kubectl apply -f base/ingress.yaml
    
    # HPA
    log_info "Konfiguracja Horizontal Pod Autoscaler..."
    kubectl apply -f base/hpa.yaml
    
    # Sprawdzenie statusu
    log_info "Sprawdzanie statusu aplikacji..."
    kubectl rollout status deployment/django-app --timeout=300s
    
    cd ../..
}

# Wyświetlenie informacji o aplikacji
show_app_info() {
    log_info "Informacje o aplikacji:"
    
    echo
    echo "Pody:"
    kubectl get pods -l app=django-app
    
    echo
    echo "Serwisy:"
    kubectl get services
    
    echo
    echo "Ingress:"
    kubectl get ingress
    
    # Pobierz URL aplikacji
    LOAD_BALANCER_URL=$(kubectl get ingress django-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    
    if [[ -n "$LOAD_BALANCER_URL" ]]; then
        echo
        log_info "Aplikacja będzie dostępna pod adresem: http://$LOAD_BALANCER_URL"
        log_warn "Może zająć kilka minut, zanim Load Balancer będzie aktywny"
    fi
}

# Główna funkcja
main() {
    echo "========================================="
    echo "Django na AWS - Terraform + Kubernetes"
    echo "========================================="
    echo
    
    check_tools
    check_aws_config
    deploy_infrastructure
    configure_kubectl
    deploy_application
    show_app_info
    
    echo
    log_info "Deployment zakończony pomyślnie!"
    log_info "Aby sprawdzić status: kubectl get pods"
    log_info "Aby zobaczyć logi: kubectl logs -l app=django-app"
}

# Uruchomienie głównej funkcji
main "$@"

---

#!/bin/bash
# scripts/destroy.sh

set -e

# Kolory dla outputu
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usunięcie aplikacji z Kubernetes
destroy_application() {
    log_info "Usuwanie aplikacji z Kubernetes..."
    
    cd deployment/kubernetes
    
    # Usunięcie wszystkich zasobów
    kubectl delete -f base/ --ignore-not-found=true
    
    # Sprawdzenie czy wszystko zostało usunięte
    log_info "Sprawdzanie czy wszystkie pody zostały usunięte..."
    kubectl wait --for=delete pod -l app=django-app --timeout=120s || true
    
    cd ../..
}

# Usunięcie infrastruktury
destroy_infrastructure() {
    log_info "Usuwanie infrastruktury..."
    
    cd deployment/terraform
    
    # Ostrzeżenie
    echo
    log_warn "UWAGA: To usunie CAŁĄ infrastrukturę włącznie z bazami danych!"
    log_warn "Ta operacja jest NIEODWRACALNA!"
    echo
    read -p "Czy na pewno chcesz kontynuować? Wpisz 'yes' aby potwierdzić: " -r
    
    if [[ $REPLY != "yes" ]]; then
        log_warn "Operacja anulowana"
        exit 0
    fi
    
    # Destroy
    terraform destroy -auto-approve
    
    log_info "Infrastruktura została usunięta"
    cd ../..
}

main() {
    echo "================================"
    echo "Usuwanie Django AWS Infrastructure"
    echo "================================"
    echo
    
    destroy_application
    destroy_infrastructure
    
    echo
    log_info "Wszystkie zasoby zostały usunięte"
}

main "$@"

---

#!/bin/bash
# scripts/update-kubeconfig.sh

set -e

# Kolory
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Sprawdzenie czy terraform został uruchomiony
check_terraform() {
    cd deployment/terraform
    
    if [[ ! -f terraform.tfstate ]] && [[ ! -f .terraform/terraform.tfstate ]]; then
        log_error "Nie znaleziono pliku state Terraform. Uruchom najpierw terraform apply"
        exit 1
    fi
    
    cd ../..
}

# Aktualizacja kubeconfig
update_kubeconfig() {
    cd deployment/terraform
    
    # Pobierz dane z Terraform outputs
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null)
    REGION=$(terraform output -raw region 2>/dev/null)
    
    if [[ -z "$CLUSTER_NAME" ]] || [[ -z "$REGION" ]]; then
        log_error "Nie można pobrać nazwy klastra lub regionu z Terraform outputs"
        exit 1
    fi
    
    cd ../..
    
    log_info "Aktualizowanie kubeconfig dla klastra: $CLUSTER_NAME w regionie: $REGION"
    
    # Aktualizacja kubeconfig
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    # Sprawdzenie połączenia
    log_info "Sprawdzanie połączenia z klastrem..."
    if kubectl get nodes &> /dev/null; then
        log_info "Połączenie z klastrem zostało nawiązane pomyślnie"
        echo
        kubectl get nodes
    else
        log_error "Nie można połączyć się z klastrem EKS"
        exit 1
    fi
}

main() {
    echo "=============================="
    echo "Aktualizacja kubeconfig dla EKS"
    echo "=============================="
    echo
    
    check_terraform
    update_kubeconfig
    
    echo
    log_info "kubeconfig został zaktualizowany"
    log_info "Możesz teraz używać kubectl do zarządzania klastrem"
}

main "$@"