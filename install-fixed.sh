#!/bin/bash

# Teable Kubernetes Installation Script (Fixed Version)
# This script provides a simple installation without color codes

set -e

# Default values
NAMESPACE="teable"
RELEASE_NAME="teable"
CHART_PATH="./teable-helm"
VALUES_FILE=""
ENVIRONMENT="development"
SKIP_DEPENDENCIES=true
DRY_RUN=false

# Function to print messages without colors
print_status() {
    echo "[INFO] $1"
}

print_success() {
    echo "[SUCCESS] $1"
}

print_warning() {
    echo "[WARNING] $1"
}

print_error() {
    echo "[ERROR] $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Teable Kubernetes Installation Script (Fixed Version)

Usage: $0 [OPTIONS]

Options:
    -n, --namespace NAMESPACE      Kubernetes namespace (default: teable)
    -r, --release RELEASE_NAME     Helm release name (default: teable)
    -f, --values VALUES_FILE       Values file to use
    -e, --environment ENV          Environment type: development, staging, production (default: development)
    -c, --chart-path PATH          Path to Helm chart (default: ./teable-helm)
    --skip-dependencies            Skip Helm dependency update (default: true)
    --with-dependencies            Enable Helm dependency update
    --dry-run                      Perform a dry run
    --use-static                   Use static manifests instead of Helm
    -h, --help                     Show this help message

Examples:
    # Install with static manifests (recommended)
    $0 --use-static

    # Install with Helm (if available)
    $0

    # Install in specific namespace
    $0 -n production --use-static

    # Dry run to see what would be installed
    $0 --dry-run

EOF
}

# Function to check prerequisites for Helm
check_helm_prerequisites() {
    print_status "Checking Helm prerequisites..."

    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed or not in PATH"
        print_status "Please install Helm: https://helm.sh/docs/intro/install/"
        print_status "Or use --use-static flag to use static manifests"
        return 1
    fi

    if [ ! -d "$CHART_PATH" ]; then
        print_error "Chart directory not found: $CHART_PATH"
        return 1
    fi

    if [ ! -f "$CHART_PATH/Chart.yaml" ]; then
        print_error "Chart.yaml not found in: $CHART_PATH"
        return 1
    fi

    print_success "Helm prerequisites check passed"
    return 0
}

# Function to check prerequisites for static installation
check_static_prerequisites() {
    print_status "Checking static installation prerequisites..."

    if [ ! -d "./k8s-manifests" ]; then
        print_status "Static manifests not found. Generating them..."
        if [ -f "./generate-k8s.sh" ]; then
            ./generate-k8s.sh
        else
            print_error "Neither k8s-manifests directory nor generate-k8s.sh script found"
            return 1
        fi
    fi

    if [ ! -f "./k8s-manifests/install.sh" ]; then
        print_error "Static installation script not found in k8s-manifests/"
        return 1
    fi

    print_success "Static installation prerequisites check passed"
    return 0
}

# Function to check common prerequisites
check_common_prerequisites() {
    print_status "Checking common prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        return 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubectl configuration."
        return 1
    fi

    print_success "Common prerequisites check passed"
    return 0
}

# Function to create namespace if it doesn't exist
create_namespace() {
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_status "Namespace '$NAMESPACE' already exists"
    else
        print_status "Creating namespace '$NAMESPACE'..."
        kubectl create namespace "$NAMESPACE"
        print_success "Namespace '$NAMESPACE' created"
    fi
}

# Function to install using static manifests
install_static() {
    print_status "Installing Teable using static manifests..."

    cd k8s-manifests

    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN - would execute the following:"
        echo "  kubectl apply -f namespace.yaml"
        echo "  kubectl apply -f configmap.yaml"
        echo "  kubectl apply -f secret.yaml"
        echo "  kubectl apply -f serviceaccount.yaml"
        echo "  kubectl apply -f service.yaml"
        echo "  kubectl apply -f deployment.yaml"
        print_success "Dry run completed"
        return 0
    fi

    print_status "Applying Kubernetes manifests..."

    echo "Creating namespace..."
    kubectl apply -f namespace.yaml

    echo "Creating ConfigMap..."
    kubectl apply -f configmap.yaml

    echo "Creating Secret..."
    kubectl apply -f secret.yaml

    echo "Creating ServiceAccount..."
    kubectl apply -f serviceaccount.yaml

    echo "Creating Service..."
    kubectl apply -f service.yaml

    echo "Creating Deployment..."
    kubectl apply -f deployment.yaml

    print_success "Static manifests applied successfully!"

    cd ..
}

# Function to install using Helm
install_helm() {
    print_status "Installing Teable using Helm..."

    local helm_cmd="helm"
    if [ "$DRY_RUN" = true ]; then
        helm_cmd="$helm_cmd template"
    else
        helm_cmd="$helm_cmd install"
    fi

    helm_cmd="$helm_cmd $RELEASE_NAME $CHART_PATH --namespace $NAMESPACE"

    if [ "$DRY_RUN" = false ]; then
        helm_cmd="$helm_cmd --create-namespace"
    fi

    if [ -n "$VALUES_FILE" ]; then
        helm_cmd="$helm_cmd -f $VALUES_FILE"
    fi

    print_status "Executing: $helm_cmd"
    echo ""

    if eval "$helm_cmd"; then
        if [ "$DRY_RUN" = false ]; then
            print_success "Teable installed successfully using Helm!"
        else
            print_success "Helm dry run completed successfully!"
        fi
    else
        print_error "Helm installation failed!"
        return 1
    fi
}

# Function to show post-installation information
show_post_install_info() {
    echo ""
    print_status "Installation completed!"
    echo ""
    print_status "Next steps:"
    echo ""
    echo "1. Check pod status:"
    echo "   kubectl get pods -n $NAMESPACE"
    echo ""
    echo "2. View application logs:"
    echo "   kubectl logs -l app.kubernetes.io/name=teable -n $NAMESPACE"
    echo ""
    echo "3. Access the application:"
    echo "   kubectl port-forward svc/$RELEASE_NAME 8080:3000 -n $NAMESPACE"
    echo "   Then visit: http://localhost:8080"
    echo ""
    print_warning "Important: Make sure external PostgreSQL, Redis, and MinIO are configured!"
    print_status "You can start dependencies with: docker-compose up -d"
    echo ""
    print_status "For status checking, run: ./check-status.sh"
}

# Parse command line arguments
USE_STATIC=false

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
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--chart-path)
            CHART_PATH="$2"
            shift 2
            ;;
        --skip-dependencies)
            SKIP_DEPENDENCIES=true
            shift
            ;;
        --with-dependencies)
            SKIP_DEPENDENCIES=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --use-static)
            USE_STATIC=true
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

# Validate environment
case $ENVIRONMENT in
    "development"|"staging"|"production")
        ;;
    *)
        print_error "Invalid environment: $ENVIRONMENT"
        print_error "Valid environments: development, staging, production"
        exit 1
        ;;
esac

# Main execution
main() {
    echo "Teable Kubernetes Installation Script (Fixed Version)"
    echo "===================================================="
    echo ""
    echo "Configuration:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Namespace: $NAMESPACE"
    echo "  Release Name: $RELEASE_NAME"
    echo "  Use Static Manifests: $USE_STATIC"
    echo "  Dry Run: $DRY_RUN"
    echo ""

    # Check common prerequisites
    if ! check_common_prerequisites; then
        exit 1
    fi

    # Choose installation method
    if [ "$USE_STATIC" = true ]; then
        print_status "Using static manifests installation method"

        if ! check_static_prerequisites; then
            exit 1
        fi

        if [ "$DRY_RUN" = false ]; then
            create_namespace
        fi

        install_static

    else
        print_status "Using Helm installation method"

        if ! check_helm_prerequisites; then
            print_status "Helm prerequisites failed. Try using --use-static flag instead."
            exit 1
        fi

        if [ "$SKIP_DEPENDENCIES" = false ]; then
            print_status "Updating Helm dependencies..."
            if helm dependency update "$CHART_PATH"; then
                print_success "Dependencies updated"
            else
                print_error "Failed to update dependencies"
                print_warning "Try using --skip-dependencies or --use-static flag"
                exit 1
            fi
        else
            print_warning "Skipping dependency update"
        fi

        if [ "$DRY_RUN" = false ]; then
            create_namespace
        fi

        install_helm
    fi

    if [ "$DRY_RUN" = false ]; then
        show_post_install_info
    fi
}

# Run main function
main "$@"
