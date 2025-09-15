#!/bin/bash

# Teable Kubernetes Status Checker
# This script checks the status of Teable deployment and its dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="teable"
RELEASE_NAME="teable"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    local all_good=true

    if command_exists kubectl; then
        print_success "kubectl is installed"

        if kubectl cluster-info >/dev/null 2>&1; then
            print_success "kubectl can connect to cluster"
        else
            print_error "kubectl cannot connect to cluster"
            all_good=false
        fi
    else
        print_error "kubectl is not installed"
        all_good=false
    fi

    if command_exists helm; then
        print_success "helm is installed"
        local helm_version=$(helm version --short 2>/dev/null | cut -d' ' -f1 || echo "unknown")
        echo "  Version: $helm_version"
    else
        print_error "helm is not installed"
        all_good=false
    fi

    if command_exists docker; then
        print_success "docker is available"
    else
        print_warning "docker is not available (optional)"
    fi

    if [ "$all_good" = false ]; then
        print_error "Some prerequisites are missing"
        return 1
    fi
}

# Function to check namespace
check_namespace() {
    print_header "Checking Namespace: $NAMESPACE"

    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_success "Namespace '$NAMESPACE' exists"

        # Show namespace details
        kubectl get namespace "$NAMESPACE" -o wide
    else
        print_error "Namespace '$NAMESPACE' does not exist"
        return 1
    fi
}

# Function to check Helm release
check_helm_release() {
    print_header "Checking Helm Release: $RELEASE_NAME"

    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_success "Helm release '$RELEASE_NAME' found"

        # Show release details
        helm status "$RELEASE_NAME" -n "$NAMESPACE"

        # Show release history
        echo ""
        print_status "Release History:"
        helm history "$RELEASE_NAME" -n "$NAMESPACE"
    else
        print_error "Helm release '$RELEASE_NAME' not found in namespace '$NAMESPACE'"

        print_status "Available releases in namespace '$NAMESPACE':"
        helm list -n "$NAMESPACE" || echo "  No releases found"
        return 1
    fi
}

# Function to check pods
check_pods() {
    print_header "Checking Pods"

    local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=teable -o name 2>/dev/null)

    if [ -z "$pods" ]; then
        print_error "No Teable pods found"
        return 1
    fi

    print_success "Found Teable pods:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=teable -o wide

    echo ""
    print_status "Pod Status Details:"

    local all_running=true

    for pod in $pods; do
        local pod_name=$(basename "$pod")
        local status=$(kubectl get "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        local ready=$(kubectl get "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

        echo "  Pod: $pod_name"
        echo "    Status: $status"
        echo "    Ready: $ready"

        if [ "$status" != "Running" ] || [ "$ready" != "True" ]; then
            all_running=false

            # Show container statuses
            print_status "Container statuses for $pod_name:"
            kubectl get "$pod" -n "$NAMESPACE" -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.state}{"\n"}{end}' | sed 's/^/    /'
        fi
    done

    if [ "$all_running" = false ]; then
        print_warning "Not all pods are running and ready"
        return 1
    else
        print_success "All pods are running and ready"
    fi
}

# Function to check services
check_services() {
    print_header "Checking Services"

    local services=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=teable -o name 2>/dev/null)

    if [ -z "$services" ]; then
        print_error "No Teable services found"
        return 1
    fi

    print_success "Found Teable services:"
    kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=teable -o wide

    # Check endpoints
    echo ""
    print_status "Service Endpoints:"
    kubectl get endpoints -n "$NAMESPACE" -l app.kubernetes.io/name=teable
}

# Function to check ingress
check_ingress() {
    print_header "Checking Ingress"

    local ingresses=$(kubectl get ingress -n "$NAMESPACE" -l app.kubernetes.io/name=teable -o name 2>/dev/null)

    if [ -z "$ingresses" ]; then
        print_warning "No Teable ingress found (this is normal if ingress is disabled)"
        return 0
    fi

    print_success "Found Teable ingress:"
    kubectl get ingress -n "$NAMESPACE" -l app.kubernetes.io/name=teable -o wide
}

# Function to check configmaps and secrets
check_config() {
    print_header "Checking Configuration"

    # Check ConfigMap
    if kubectl get configmap "$RELEASE_NAME-config" -n "$NAMESPACE" >/dev/null 2>&1; then
        print_success "ConfigMap '$RELEASE_NAME-config' exists"

        print_status "ConfigMap keys:"
        kubectl get configmap "$RELEASE_NAME-config" -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || kubectl get configmap "$RELEASE_NAME-config" -n "$NAMESPACE" -o jsonpath='{.data}' | grep -o '"[^"]*"' | sed 's/"//g' | head -10
    else
        print_error "ConfigMap '$RELEASE_NAME-config' not found"
    fi

    # Check Secret
    if kubectl get secret "$RELEASE_NAME-secret" -n "$NAMESPACE" >/dev/null 2>&1; then
        print_success "Secret '$RELEASE_NAME-secret' exists"

        print_status "Secret keys:"
        kubectl get secret "$RELEASE_NAME-secret" -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || kubectl get secret "$RELEASE_NAME-secret" -n "$NAMESPACE" -o jsonpath='{.data}' | grep -o '"[^"]*"' | sed 's/"//g'
    else
        print_error "Secret '$RELEASE_NAME-secret' not found"
    fi
}

# Function to check application health
check_app_health() {
    print_header "Checking Application Health"

    local pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=teable -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -z "$pod" ]; then
        print_error "No pod available for health check"
        return 1
    fi

    print_status "Testing health endpoint on pod: $pod"

    if kubectl exec "$pod" -n "$NAMESPACE" -- curl -f -s http://localhost:3000/health >/dev/null 2>&1; then
        print_success "Health endpoint is responding"

        # Show health response
        local health_response=$(kubectl exec "$pod" -n "$NAMESPACE" -- curl -s http://localhost:3000/health 2>/dev/null)
        echo "  Response: $health_response"
    else
        print_error "Health endpoint is not responding"

        print_status "Checking if port 3000 is listening:"
        kubectl exec "$pod" -n "$NAMESPACE" -- netstat -ln | grep :3000 || print_warning "Port 3000 not found"

        return 1
    fi
}

# Function to check logs
check_logs() {
    print_header "Recent Application Logs"

    print_status "Last 20 lines of Teable logs:"
    kubectl logs -l app.kubernetes.io/name=teable -n "$NAMESPACE" --tail=20 || print_error "Could not retrieve logs"

    echo ""
    print_status "Checking for common error patterns:"

    local error_found=false

    # Check for database connection errors
    if kubectl logs -l app.kubernetes.io/name=teable -n "$NAMESPACE" --tail=100 | grep -i "database\|postgres\|connection" | grep -i "error\|failed\|refused" >/dev/null 2>&1; then
        print_warning "Database connection issues detected"
        error_found=true
    fi

    # Check for Redis connection errors
    if kubectl logs -l app.kubernetes.io/name=teable -n "$NAMESPACE" --tail=100 | grep -i "redis" | grep -i "error\|failed\|refused" >/dev/null 2>&1; then
        print_warning "Redis connection issues detected"
        error_found=true
    fi

    # Check for MinIO/storage errors
    if kubectl logs -l app.kubernetes.io/name=teable -n "$NAMESPACE" --tail=100 | grep -i "minio\|storage\|bucket" | grep -i "error\|failed" >/dev/null 2>&1; then
        print_warning "Storage/MinIO issues detected"
        error_found=true
    fi

    if [ "$error_found" = false ]; then
        print_success "No obvious error patterns found in recent logs"
    fi
}

# Function to check external dependencies
check_external_deps() {
    print_header "Checking External Dependencies"

    print_status "Checking Docker Compose services (if running):"

    if command_exists docker-compose || command_exists docker; then
        if [ -f "docker-compose.yml" ]; then
            if command_exists docker-compose; then
                docker-compose ps 2>/dev/null || print_warning "Docker Compose not running or no services found"
            else
                print_warning "docker-compose command not found, checking with docker"
                docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(postgres|redis|minio)" || print_warning "No external dependency containers found"
            fi
        else
            print_warning "docker-compose.yml not found in current directory"
        fi
    else
        print_warning "Docker not available"
    fi
}

# Function to show access information
show_access_info() {
    print_header "Access Information"

    print_status "To access Teable application:"
    echo "  kubectl port-forward svc/$RELEASE_NAME 8080:3000 -n $NAMESPACE"
    echo "  Then visit: http://localhost:8080"
    echo ""

    # Check if ingress is configured
    local ingress_hosts=$(kubectl get ingress -n "$NAMESPACE" -l app.kubernetes.io/name=teable -o jsonpath='{.items[*].spec.rules[*].host}' 2>/dev/null)
    if [ -n "$ingress_hosts" ]; then
        print_status "Ingress hosts configured:"
        for host in $ingress_hosts; do
            echo "  - https://$host (if TLS is configured)"
            echo "  - http://$host"
        done
        echo ""
    fi

    print_status "Useful commands:"
    echo "  # View logs"
    echo "  kubectl logs -l app.kubernetes.io/name=teable -n $NAMESPACE -f"
    echo ""
    echo "  # Get shell access"
    echo "  kubectl exec -it deployment/$RELEASE_NAME -n $NAMESPACE -- /bin/sh"
    echo ""
    echo "  # Check all resources"
    echo "  kubectl get all -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE"
}

# Function to show usage
show_usage() {
    cat << EOF
Teable Kubernetes Status Checker

Usage: $0 [OPTIONS]

Options:
    -n, --namespace NAMESPACE      Kubernetes namespace (default: teable)
    -r, --release RELEASE_NAME     Helm release name (default: teable)
    --logs                         Show detailed logs
    --no-deps                      Skip external dependency checks
    -h, --help                     Show this help message

Examples:
    $0                             # Check status with defaults
    $0 -n teable-prod -r teable-prod  # Check production deployment
    $0 --logs                      # Include detailed log analysis

EOF
}

# Parse command line arguments
SHOW_LOGS=false
CHECK_DEPS=true

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        --logs)
            SHOW_LOGS=true
            shift
            ;;
        --no-deps)
            CHECK_DEPS=false
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "🔍 Teable Kubernetes Status Checker"
    echo "===================================="
    echo "Namespace: $NAMESPACE"
    echo "Release: $RELEASE_NAME"
    echo ""

    local overall_status=0

    # Run all checks
    check_prerequisites || overall_status=1
    check_namespace || overall_status=1
    check_helm_release || overall_status=1
    check_pods || overall_status=1
    check_services || overall_status=1
    check_ingress
    check_config || overall_status=1
    check_app_health || overall_status=1

    if [ "$SHOW_LOGS" = true ]; then
        check_logs
    fi

    if [ "$CHECK_DEPS" = true ]; then
        check_external_deps
    fi

    show_access_info

    # Overall status
    print_header "Overall Status"

    if [ $overall_status -eq 0 ]; then
        print_success "✅ Teable deployment appears to be healthy!"
    else
        print_warning "⚠️  Some issues were detected. Please review the output above."
        print_status "For troubleshooting, try:"
        echo "  - Check logs: kubectl logs -l app.kubernetes.io/name=teable -n $NAMESPACE"
        echo "  - Describe pods: kubectl describe pods -l app.kubernetes.io/name=teable -n $NAMESPACE"
        echo "  - Check events: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
    fi

    return $overall_status
}

# Run main function
main "$@"
