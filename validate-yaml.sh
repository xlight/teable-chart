#!/bin/bash

# YAML Validation Script
# Validates YAML syntax without requiring Helm

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

# Function to validate YAML syntax
validate_yaml_file() {
    local file="$1"
    local filename=$(basename "$file")

    echo -n "  Validating $filename... "

    # Try Python first
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
            return 0
        else
            echo -e "${RED}✗${NC}"
            python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>&1 | sed 's/^/    /'
            return 1
        fi
    # Try ruby as fallback
    elif command -v ruby >/dev/null 2>&1; then
        if ruby -ryaml -e "YAML.load_file('$file')" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
            return 0
        else
            echo -e "${RED}✗${NC}"
            ruby -ryaml -e "YAML.load_file('$file')" 2>&1 | sed 's/^/    /'
            return 1
        fi
    # Try node as fallback
    elif command -v node >/dev/null 2>&1; then
        if node -e "require('fs').readFileSync('$file', 'utf8').split('---').forEach(doc => { if(doc.trim()) require('yaml').parse ? require('yaml').parse(doc) : console.log('YAML parsing not available') })" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
            return 0
        else
            echo -e "${RED}✗${NC} (Node.js YAML validation limited)"
            return 1
        fi
    else
        echo -e "${YELLOW}?${NC} (No YAML validator available)"
        print_warning "Install python3, ruby, or node.js for proper YAML validation"
        return 0
    fi
}

# Function to check basic file structure
check_file_structure() {
    local file="$1"
    local filename=$(basename "$file")

    echo -n "  Checking $filename structure... "

    # Basic checks for Kubernetes YAML files
    if grep -q "apiVersion:" "$file" && grep -q "kind:" "$file" && grep -q "metadata:" "$file"; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${YELLOW}?${NC} (Not a standard Kubernetes resource)"
        return 0
    fi
}

# Function to check Helm template syntax
check_helm_templates() {
    local template_dir="$1"

    print_status "Checking Helm template syntax..."

    local template_errors=0

    find "$template_dir" -name "*.yaml" -o -name "*.yml" -o -name "*.tpl" | while read -r file; do
        local filename=$(basename "$file")
        echo -n "  Checking $filename for template syntax... "

        # Check for common Helm template issues
        local issues=""

        # Check for unclosed template blocks
        if grep -n "{{[^}]*$" "$file" >/dev/null 2>&1; then
            issues="$issues unclosed-template-block"
        fi

        # Check for unmatched quotes in templates
        if grep -n '{{.*"[^"]*$' "$file" >/dev/null 2>&1; then
            issues="$issues unmatched-quotes"
        fi

        # Check for common template function errors
        if grep -n "{{ *\." "$file" | grep -v "{{ *\.[A-Za-z]" >/dev/null 2>&1; then
            issues="$issues invalid-dot-reference"
        fi

        if [ -z "$issues" ]; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC} ($issues)"
            template_errors=$((template_errors + 1))
        fi
    done

    return $template_errors
}

# Function to validate Chart.yaml
validate_chart_yaml() {
    local chart_file="$1"

    print_status "Validating Chart.yaml..."

    if [ ! -f "$chart_file" ]; then
        print_error "Chart.yaml not found at: $chart_file"
        return 1
    fi

    echo -n "  Checking Chart.yaml syntax... "
    if validate_yaml_file "$chart_file"; then
        echo -n "  Checking required fields... "

        local required_fields=("apiVersion" "name" "version")
        local missing_fields=""

        for field in "${required_fields[@]}"; do
            if ! grep -q "^$field:" "$chart_file"; then
                missing_fields="$missing_fields $field"
            fi
        done

        if [ -z "$missing_fields" ]; then
            echo -e "${GREEN}✓${NC}"
            return 0
        else
            echo -e "${RED}✗${NC} (missing:$missing_fields)"
            return 1
        fi
    else
        return 1
    fi
}

# Function to validate values files
validate_values_files() {
    local chart_dir="$1"

    print_status "Validating values files..."

    local values_files=$(find "$chart_dir" -maxdepth 1 -name "values*.yaml" -o -name "values*.yml")

    if [ -z "$values_files" ]; then
        print_warning "No values files found"
        return 0
    fi

    local values_errors=0

    for file in $values_files; do
        if ! validate_yaml_file "$file"; then
            values_errors=$((values_errors + 1))
        fi
    done

    return $values_errors
}

# Function to validate template files
validate_template_files() {
    local template_dir="$1"

    print_status "Validating template files..."

    if [ ! -d "$template_dir" ]; then
        print_error "Templates directory not found: $template_dir"
        return 1
    fi

    local template_files=$(find "$template_dir" -name "*.yaml" -o -name "*.yml")

    if [ -z "$template_files" ]; then
        print_warning "No template files found"
        return 0
    fi

    local template_errors=0

    for file in $template_files; do
        # Skip validation for files with heavy templating
        if grep -q "{{.*}}" "$file"; then
            echo "  Skipping $(basename "$file") (contains Helm templates)"
            continue
        fi

        if ! validate_yaml_file "$file"; then
            template_errors=$((template_errors + 1))
        fi

        if ! check_file_structure "$file"; then
            template_errors=$((template_errors + 1))
        fi
    done

    return $template_errors
}

# Main validation function
main() {
    local chart_path="${1:-./teable-helm}"

    echo "🔍 YAML Validation for Helm Chart"
    echo "=================================="
    echo "Chart path: $chart_path"
    echo ""

    if [ ! -d "$chart_path" ]; then
        print_error "Chart directory not found: $chart_path"
        exit 1
    fi

    local total_errors=0

    # Validate Chart.yaml
    if ! validate_chart_yaml "$chart_path/Chart.yaml"; then
        total_errors=$((total_errors + 1))
    fi

    # Validate values files
    if ! validate_values_files "$chart_path"; then
        total_errors=$((total_errors + 1))
    fi

    # Validate template files
    if ! validate_template_files "$chart_path/templates"; then
        total_errors=$((total_errors + 1))
    fi

    # Check Helm template syntax
    if ! check_helm_templates "$chart_path/templates"; then
        total_errors=$((total_errors + 1))
    fi

    echo ""
    echo "=================================="

    if [ $total_errors -eq 0 ]; then
        print_success "✅ All validations passed!"
        echo ""
        print_status "Your Helm chart appears to be syntactically correct."
        print_status "Note: This validation cannot catch all Helm template logic errors."
        print_status "Run 'helm template' when Helm is available for complete validation."
    else
        print_error "❌ $total_errors validation error(s) found."
        echo ""
        print_status "Please fix the errors above before proceeding."
        exit 1
    fi
}

# Show usage
show_usage() {
    cat << EOF
YAML Validation Script for Helm Charts

Usage: $0 [CHART_PATH]

Arguments:
    CHART_PATH    Path to Helm chart directory (default: ./teable-helm)

Examples:
    $0                    # Validate chart in ./teable-helm
    $0 ./my-chart         # Validate chart in ./my-chart

This script validates:
- Chart.yaml syntax and required fields
- values.yaml files syntax
- Template file YAML syntax (where possible)
- Basic Helm template syntax issues

Requirements:
- python3 (recommended) or ruby or node.js for YAML parsing

EOF
}

# Parse arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

# Run main function
main "$@"
