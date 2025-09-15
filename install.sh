#!/bin/bash

# Teable Helm Chart Installation Script
# This script helps install Teable on Kubernetes using Helm

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
VALUES_FILE=""
CHART_PATH="./teable-helm"
ENVIRONMENT="development"
SKIP_DEPENDENCIES=true
DRY_RUN=false

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

# Function to show usage
show_usage() {
    cat << EOF
Teable Helm Chart Installation Script

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
    -h, --help                     Show this help message

Examples:
    # Install with default settings (development)
    $0

    # Install for production
    $0 -e production -n teable-prod -r teable-prod

    # Install with custom values file
    $0 -f my-values.yaml

    # Dry run to see what would be installed
    $0 --dry-run

    # Install in specific namespace with custom release name
    $0 -n my-namespace -r my-teable

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if kubectl is installed and configured
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi

    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubectl configuration."
        exit 1
    fi

    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed or not in PATH"
        print_status "Please install Helm: https://helm.sh/docs/intro/install/"
        exit 1
    fi

    # Check if chart directory exists
    if [ ! -d "$CHART_PATH" ]; then
        print_error "Chart directory not found: $CHART_PATH"
        exit 1
    fi

    print_success "Prerequisites check passed"
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

# Function to update Helm dependencies
update_dependencies() {
    if [ "$SKIP_DEPENDENCIES" = false ]; then
        print_status "Updating Helm dependencies..."
        if helm dependency update "$CHART_PATH"; then
            print_success "Dependencies updated"
        else
            print_error "Failed to update dependencies"
            print_warning "You may need to add Bitnami repository:"
            print_warning "helm repo add bitnami https://charts.bitnami.com/bitnami"
            print_warning "helm repo update"
            print_warning "Or use --skip-dependencies to install without dependencies"
            exit 1
        fi
    else
        print_warning "Skipping dependency update (using external services)"
    fi
}

# Function to validate values file
validate_values() {
    if [ -n "$VALUES_FILE" ] && [ ! -f "$VALUES_FILE" ]; then
        print_error "Values file not found: $VALUES_FILE"
        exit 1
    fi
}

# Function to generate installation command
generate_helm_command() {
    local cmd="helm"

    if [ "$DRY_RUN" = true ]; then
        cmd="$cmd template"
    else
        cmd="$cmd install"
    fi

    cmd="$cmd $RELEASE_NAME $CHART_PATH"
    cmd="$cmd --namespace $NAMESPACE"

    if [ "$DRY_RUN" = false ]; then
        cmd="$cmd --create-namespace"
    fi

    # Add values file based on environment if not specified
    if [ -z "$VALUES_FILE" ]; then
        case $ENVIRONMENT in
            "production")
                if [ -f "$CHART_PATH/values-prod.yaml" ]; then
                    cmd="$cmd -f $CHART_PATH/values-prod.yaml"
                    print_status "Using production values file"
                fi
                ;;
            "staging")
                if [ -f "$CHART_PATH/values-staging.yaml" ]; then
                    cmd="$cmd -f $CHART_PATH/values-staging.yaml"
                    print_status "Using staging values file"
                fi
                ;;
            *)
                print_status "Using default development values"
                ;;
        esac
    else
        cmd="$cmd -f $VALUES_FILE"
        print_status "Using custom values file: $VALUES_FILE"
    fi

    echo "$cmd"
}

# Function to show pre-installation summary
show_summary() {
    print_status "Installation Summary:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Namespace: $NAMESPACE"
    echo "  Release Name: $RELEASE_NAME"
    echo "  Chart Path: $CHART_PATH"
    if [ -n "$VALUES_FILE" ]; then
        echo "  Values File: $VALUES_FILE"
    fi
    echo "  Dry Run: $DRY_RUN"
    echo ""
}

# Function to perform installation
install_teable() {
    local helm_cmd
    helm_cmd=$(generate_helm_command)

    print_status "Executing: $helm_cmd"
    echo ""

    if eval "$helm_cmd"; then
        if [ "$DRY_RUN" = false ]; then
            print_success "Teable installed successfully!"
            show_post_install_info
        else
            print_success "Dry run completed successfully!"
        fi
    else
        print_error "Installation failed!"
        exit 1
    fi
}

# Function to show post-installation information
show_post_install_info() {
    echo ""
    print_status "Post-installation information:"
    echo ""

    # Show how to get application URL
    print_status "To get the application URL, run:"
    echo "  kubectl get ingress -n $NAMESPACE"
    echo ""

    # Show how to check status
    print_status "To check the status of your deployment:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  kubectl get svc -n $NAMESPACE"
    echo ""

    # Show how to view logs
    print_status "To view application logs:"
    echo "  kubectl logs -l app.kubernetes.io/name=teable -n $NAMESPACE -f"
    echo ""

    # Show how to access via port-forward if no ingress
    print_status "To access via port-forward (if no ingress configured):"
    echo "  kubectl port-forward svc/$RELEASE_NAME 8080:3000 -n $NAMESPACE"
    echo "  Then visit: http://localhost:8080"
    echo ""

    # Environment-specific information
    case $ENVIRONMENT in
        "production")
            print_warning "PRODUCTION DEPLOYMENT CHECKLIST:"
            echo "  □ Update JWT and session secrets in values file"
            echo "  □ Configure proper TLS certificates"
            echo "  □ Set up monitoring and alerting"
            echo "  □ Configure backup strategy"
            echo "  □ Review security settings"
            ;;
        "development")
            print_status "Development deployment completed."
            print_warning "Remember to update secrets before using in production!"
            ;;
    esac

    echo ""
    print_status "For more information, see the chart README.md"
}

# Function to handle cleanup on script exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Installation failed. Check the error messages above."
        print_status "For troubleshooting help, run:"
        echo "  kubectl describe pods -n $NAMESPACE"
        echo "  kubectl logs -l app.kubernetes.io/name=teable -n $NAMESPACE"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Parse command line arguments
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
    echo "🚀 Teable Helm Chart Installation Script"
    echo "========================================"
    echo ""

    check_prerequisites
    validate_values
    show_summary

    # Confirm installation (skip for dry run)
    if [ "$DRY_RUN" = false ]; then
        read -p "Proceed with installation? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Installation cancelled."
            exit 0
        fi
    fi

    if [ "$DRY_RUN" = false ]; then
        create_namespace
    fi

    # Only update dependencies if not skipping
    if [ "$SKIP_DEPENDENCIES" = false ]; then
        update_dependencies
    else
        print_warning "Dependencies are disabled. Make sure you have external PostgreSQL, Redis, and MinIO configured."
        print_status "Using standalone configuration..."
    fi

    install_teable
}

# Run main function
main "$@"
