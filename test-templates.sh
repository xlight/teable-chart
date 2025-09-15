#!/bin/bash

# Script to test Helm templates without actually installing
# This validates that the templates generate valid Kubernetes manifests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_PATH="${SCRIPT_DIR}/teable-helm"
OUTPUT_DIR="${SCRIPT_DIR}/test-output"
NAMESPACE="teable-test"
RELEASE_NAME="teable-test"

print_status "Testing Helm templates..."
print_status "Script directory: $SCRIPT_DIR"
print_status "Chart path: $CHART_PATH"

# Check if Helm is available
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed or not in PATH"
    print_status "You can install Helm from: https://helm.sh/docs/intro/install/"
    print_status "Alternative: Use './generate-k8s.sh' to create static manifests"
    exit 1
fi

# Check if chart directory exists
if [ ! -d "$CHART_PATH" ]; then
    print_error "Chart directory not found: $CHART_PATH"
    print_error "Expected path: $CHART_PATH"
    print_status "Current working directory: $(pwd)"
    print_status "Available directories:"
    ls -la "$SCRIPT_DIR" | grep "^d"
    exit 1
fi

# Verify Chart.yaml exists
if [ ! -f "$CHART_PATH/Chart.yaml" ]; then
    print_error "Chart.yaml not found in: $CHART_PATH"
    print_status "Directory contents:"
    ls -la "$CHART_PATH"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

print_status "Generating templates..."

# Test with default values
print_status "Testing with default values..."
if helm template "$RELEASE_NAME" "$CHART_PATH" \
    --namespace "$NAMESPACE" \
    --output-dir "$OUTPUT_DIR/default" \
    --debug; then
    print_success "Default values template generation successful"
else
    print_error "Failed to generate templates with default values"
    exit 1
fi

# Test with standalone values
if [ -f "$CHART_PATH/values-standalone.yaml" ]; then
    print_status "Testing with standalone values..."
    if helm template "$RELEASE_NAME" "$CHART_PATH" \
        --namespace "$NAMESPACE" \
        --values "$CHART_PATH/values-standalone.yaml" \
        --output-dir "$OUTPUT_DIR/standalone" \
        --debug; then
        print_success "Standalone values template generation successful"
    else
        print_error "Failed to generate templates with standalone values"
        exit 1
    fi
fi

# Test with production values
if [ -f "$CHART_PATH/values-prod.yaml" ]; then
    print_status "Testing with production values..."
    if helm template "$RELEASE_NAME" "$CHART_PATH" \
        --namespace "$NAMESPACE" \
        --values "$CHART_PATH/values-prod.yaml" \
        --output-dir "$OUTPUT_DIR/production" \
        --debug; then
        print_success "Production values template generation successful"
    else
        print_error "Failed to generate templates with production values"
        exit 1
    fi
fi

# Lint the chart
print_status "Linting Helm chart..."
if helm lint "$CHART_PATH"; then
    print_success "Chart lint successful"
else
    print_error "Chart lint failed"
    exit 1
fi

# Show generated files
print_status "Generated template files:"
find "$OUTPUT_DIR" -name "*.yaml" | sort | while read file; do
    echo "  - $file"
done

# Validate YAML syntax if Python is available
if command -v python3 &> /dev/null; then
    print_status "Validating YAML syntax..."
    yaml_valid=true

    find "$OUTPUT_DIR" -name "*.yaml" | while read file; do
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $file"
        else
            echo -e "  ${RED}✗${NC} $file"
            yaml_valid=false
        fi
    done

    if [ "$yaml_valid" = true ]; then
        print_success "All YAML files are valid"
    else
        print_warning "Some YAML files have syntax issues"
    fi
else
    print_warning "Python3 not available, skipping YAML validation"
fi

# Show sample resources
print_status "Sample generated resources:"
echo ""

# Show ConfigMap
if [ -f "$OUTPUT_DIR/default/teable/templates/configmap.yaml" ]; then
    echo "ConfigMap (first 20 lines):"
    head -20 "$OUTPUT_DIR/default/teable/templates/configmap.yaml"
    echo "..."
    echo ""
fi

# Show Deployment
if [ -f "$OUTPUT_DIR/default/teable/templates/deployment.yaml" ]; then
    echo "Deployment (container spec):"
    grep -A 10 "containers:" "$OUTPUT_DIR/default/teable/templates/deployment.yaml" || true
    echo "..."
    echo ""
fi

# Show Service
if [ -f "$OUTPUT_DIR/default/teable/templates/service.yaml" ]; then
    echo "Service:"
    cat "$OUTPUT_DIR/default/teable/templates/service.yaml"
    echo ""
fi

print_success "Template testing completed!"
print_status "Generated files are available in: $OUTPUT_DIR"
print_status "You can review the generated manifests before deploying"

# Cleanup option
read -p "Do you want to clean up generated files? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$OUTPUT_DIR"
    print_success "Cleanup completed"
else
    print_status "Generated files preserved in $OUTPUT_DIR"
fi
