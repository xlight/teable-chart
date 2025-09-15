#!/bin/bash

# Simple Teable Installation Script
# This script installs Teable without complex dependency checking

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_PATH="${SCRIPT_DIR}/teable-helm"

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
Simple Teable Installation Script

Usage: $0 [OPTIONS]

Options:
    -n, --namespace NAMESPACE      Kubernetes namespace (default: teable)
    -r, --release RELEASE_NAME     Helm release name (default: teable)
    -c, --chart-path PATH          Path to Helm chart (default: ./teable-helm)
    --dry-run                      Show what would be installed
    -h, --help                     Show this help message

Examples:
    $0                             # Install with defaults
    $0 -n my-namespace             # Install in specific namespace
    $0 --dry-run                   # Show what would be installed

EOF
}

# Parse command line arguments
DRY_RUN=false

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
        -c|--chart-path)
            CHART_PATH="$2"
            shift 2
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

# Main installation function
main() {
    echo "🚀 Simple Teable Installation"
    echo "============================="
    echo "Namespace: $NAMESPACE"
    echo "Release: $RELEASE_NAME"
    echo "Chart Path: $CHART_PATH"
    echo "Script Directory: $SCRIPT_DIR"
    echo ""

    # Check prerequisites
    print_status "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed"
        print_status "Install Helm from: https://helm.sh/docs/intro/install/"
        exit 1
    fi

    if [ ! -d "$CHART_PATH" ]; then
        print_error "Chart directory not found: $CHART_PATH"
        print_status "Current working directory: $(pwd)"
        print_status "Script directory: $SCRIPT_DIR"
        exit 1
    fi

    if [ ! -f "$CHART_PATH/Chart.yaml" ]; then
        print_error "Chart.yaml not found in: $CHART_PATH"
        print_status "Directory contents:"
        ls -la "$CHART_PATH" 2>/dev/null || echo "Directory not accessible"
        exit 1
    fi

    print_success "Prerequisites check passed"

    # Create namespace if it doesn't exist (unless dry run)
    if [ "$DRY_RUN" = false ]; then
        if kubectl get namespace "$NAMESPACE" &> /dev/null; then
            print_status "Namespace '$NAMESPACE' already exists"
        else
            print_status "Creating namespace '$NAMESPACE'..."
            kubectl create namespace "$NAMESPACE"
            print_success "Namespace created"
        fi
    fi

    # Install with Helm
    print_status "Installing Teable..."

    local helm_cmd="helm"
    if [ "$DRY_RUN" = true ]; then
        helm_cmd="$helm_cmd template"
        print_status "DRY RUN - showing what would be installed:"
    else
        helm_cmd="$helm_cmd install"
    fi

    helm_cmd="$helm_cmd $RELEASE_NAME $CHART_PATH --namespace $NAMESPACE"

    if [ "$DRY_RUN" = false ]; then
        helm_cmd="$helm_cmd --create-namespace"
    fi

    print_status "Executing: $helm_cmd"
    echo ""

    if eval "$helm_cmd"; then
        if [ "$DRY_RUN" = false ]; then
            print_success "Teable installed successfully!"

            echo ""
            print_status "Next steps:"
            echo "1. Check pod status:"
            echo "   kubectl get pods -n $NAMESPACE"
            echo ""
            echo "2. View logs:"
            echo "   kubectl logs -l app.kubernetes.io/name=teable -n $NAMESPACE"
            echo ""
            echo "3. Access the application:"
            echo "   kubectl port-forward svc/$RELEASE_NAME 8080:3000 -n $NAMESPACE"
            echo "   Then visit: http://localhost:8080"
            echo ""
            print_warning "Note: Make sure external PostgreSQL, Redis, and MinIO are configured!"
            print_status "You can start dependencies with: docker-compose up -d"
        else
            print_success "Dry run completed successfully!"
        fi
    else
        print_error "Installation failed!"
        echo ""
        print_status "Troubleshooting steps:"
        echo "1. Check if the chart is valid:"
        echo "   helm lint $CHART_PATH"
        echo ""
        echo "2. Check cluster connectivity:"
        echo "   kubectl cluster-info"
        echo ""
        echo "3. Check namespace permissions:"
        echo "   kubectl auth can-i create pods --namespace $NAMESPACE"

        exit 1
    fi
}

# Run main function
main "$@"
