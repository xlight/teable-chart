#!/bin/bash

# Teable Kubernetes Manifests Verification Script
# This script verifies the generated manifests without requiring kubectl

set -e

# Colors (compatible with most terminals)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Function to print colored output safely
print_status() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

print_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

print_header() {
    echo ""
    printf "${BLUE}================================================${NC}\n"
    printf "${BLUE} %s${NC}\n" "$1"
    printf "${BLUE}================================================${NC}\n"
}

# Function to check if directory exists
check_manifests_directory() {
    local manifests_dir="k8s-manifests"

    print_header "Checking Manifests Directory"

    if [ ! -d "$manifests_dir" ]; then
        print_error "Manifests directory not found: $manifests_dir"
        print_status "Run './generate-k8s.sh' to generate manifests first"
        return 1
    fi

    print_success "Manifests directory found: $manifests_dir"

    # List contents
    print_status "Directory contents:"
    ls -la "$manifests_dir" | while read -r line; do
        echo "  $line"
    done

    return 0
}

# Function to validate YAML syntax
validate_yaml_syntax() {
    local file="$1"
    local filename=$(basename "$file")

    # Try different YAML validators
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    elif command -v ruby >/dev/null 2>&1; then
        if ruby -ryaml -e "YAML.load_file('$file')" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    elif command -v node >/dev/null 2>&1; then
        # Basic syntax check with node
        if node -e "
            const fs = require('fs');
            const content = fs.readFileSync('$file', 'utf8');
            // Basic YAML syntax validation
            if (content.includes('apiVersion:') && content.includes('kind:')) {
                process.exit(0);
            } else {
                process.exit(1);
            }
        " 2>/dev/null; then
            return 0
        else
            return 1
        fi
    else
        # Fallback: basic structure check
        if grep -q "apiVersion:" "$file" && grep -q "kind:" "$file" && grep -q "metadata:" "$file"; then
            return 0
        else
            return 1
        fi
    fi
}

# Function to check required files
check_required_files() {
    print_header "Checking Required Files"

    local manifests_dir="k8s-manifests"
    local required_files=(
        "namespace.yaml"
        "configmap.yaml"
        "secret.yaml"
        "serviceaccount.yaml"
        "deployment.yaml"
        "service.yaml"
        "install.sh"
        "uninstall.sh"
        "README.md"
    )

    local missing_files=0

    for file in "${required_files[@]}"; do
        local filepath="$manifests_dir/$file"
        printf "  Checking %-20s ... " "$file"

        if [ -f "$filepath" ]; then
            printf "${GREEN}✓${NC}\n"
        else
            printf "${RED}✗${NC}\n"
            missing_files=$((missing_files + 1))
        fi
    done

    if [ $missing_files -eq 0 ]; then
        print_success "All required files present"
        return 0
    else
        print_error "$missing_files required files are missing"
        return 1
    fi
}

# Function to validate YAML files
validate_yaml_files() {
    print_header "Validating YAML Syntax"

    local manifests_dir="k8s-manifests"
    local yaml_files=$(find "$manifests_dir" -name "*.yaml" 2>/dev/null)

    if [ -z "$yaml_files" ]; then
        print_error "No YAML files found in $manifests_dir"
        return 1
    fi

    local invalid_files=0

    for file in $yaml_files; do
        local filename=$(basename "$file")
        printf "  Validating %-20s ... " "$filename"

        if validate_yaml_syntax "$file"; then
            printf "${GREEN}✓${NC}\n"
        else
            printf "${RED}✗${NC}\n"
            invalid_files=$((invalid_files + 1))
        fi
    done

    if [ $invalid_files -eq 0 ]; then
        print_success "All YAML files have valid syntax"
        return 0
    else
        print_error "$invalid_files YAML files have syntax errors"
        return 1
    fi
}

# Function to check Kubernetes resource structure
check_k8s_resources() {
    print_header "Checking Kubernetes Resource Structure"

    local manifests_dir="k8s-manifests"
    local yaml_files=$(find "$manifests_dir" -name "*.yaml" 2>/dev/null)

    local invalid_resources=0

    for file in $yaml_files; do
        local filename=$(basename "$file")
        printf "  Checking %-20s ... " "$filename"

        # Skip ingress.yaml as it might be commented out
        if [ "$filename" = "ingress.yaml" ]; then
            printf "${YELLOW}SKIP${NC} (optional)\n"
            continue
        fi

        # Check required Kubernetes fields
        if grep -q "apiVersion:" "$file" && grep -q "kind:" "$file" && grep -q "metadata:" "$file"; then
            # Check for name in metadata
            if grep -A 5 "metadata:" "$file" | grep -q "name:"; then
                printf "${GREEN}✓${NC}\n"
            else
                printf "${RED}✗${NC} (missing name)\n"
                invalid_resources=$((invalid_resources + 1))
            fi
        else
            printf "${RED}✗${NC} (missing required fields)\n"
            invalid_resources=$((invalid_resources + 1))
        fi
    done

    if [ $invalid_resources -eq 0 ]; then
        print_success "All Kubernetes resources have valid structure"
        return 0
    else
        print_error "$invalid_resources resources have structural issues"
        return 1
    fi
}

# Function to check configuration values
check_configuration() {
    print_header "Checking Configuration Values"

    local manifests_dir="k8s-manifests"
    local configmap_file="$manifests_dir/configmap.yaml"
    local secret_file="$manifests_dir/secret.yaml"

    local config_issues=0

    # Check ConfigMap
    if [ -f "$configmap_file" ]; then
        printf "  ConfigMap PUBLIC_ORIGIN     ... "
        if grep -q "PUBLIC_ORIGIN:" "$configmap_file"; then
            printf "${GREEN}✓${NC}\n"
        else
            printf "${RED}✗${NC}\n"
            config_issues=$((config_issues + 1))
        fi

        printf "  ConfigMap STORAGE_PROVIDER   ... "
        if grep -q "BACKEND_STORAGE_PROVIDER:" "$configmap_file"; then
            printf "${GREEN}✓${NC}\n"
        else
            printf "${RED}✗${NC}\n"
            config_issues=$((config_issues + 1))
        fi
    else
        print_error "ConfigMap file not found"
        config_issues=$((config_issues + 1))
    fi

    # Check Secret
    if [ -f "$secret_file" ]; then
        printf "  Secret DATABASE_URL          ... "
        if grep -q "PRISMA_DATABASE_URL:" "$secret_file"; then
            printf "${GREEN}✓${NC}\n"
        else
            printf "${RED}✗${NC}\n"
            config_issues=$((config_issues + 1))
        fi

        printf "  Secret JWT_SECRET            ... "
        if grep -q "BACKEND_JWT_SECRET:" "$secret_file"; then
            printf "${GREEN}✓${NC}\n"
        else
            printf "${RED}✗${NC}\n"
            config_issues=$((config_issues + 1))
        fi

        printf "  Secret REDIS_URI             ... "
        if grep -q "BACKEND_CACHE_REDIS_URI:" "$secret_file"; then
            printf "${GREEN}✓${NC}\n"
        else
            printf "${RED}✗${NC}\n"
            config_issues=$((config_issues + 1))
        fi
    else
        print_error "Secret file not found"
        config_issues=$((config_issues + 1))
    fi

    if [ $config_issues -eq 0 ]; then
        print_success "All configuration values present"
        return 0
    else
        print_error "$config_issues configuration issues found"
        return 1
    fi
}

# Function to check deployment configuration
check_deployment() {
    print_header "Checking Deployment Configuration"

    local manifests_dir="k8s-manifests"
    local deployment_file="$manifests_dir/deployment.yaml"

    if [ ! -f "$deployment_file" ]; then
        print_error "Deployment file not found"
        return 1
    fi

    local deployment_issues=0

    printf "  Init container (db-migrate)   ... "
    if grep -q "name: db-migrate" "$deployment_file"; then
        printf "${GREEN}✓${NC}\n"
    else
        printf "${RED}✗${NC}\n"
        deployment_issues=$((deployment_issues + 1))
    fi

    printf "  Main container image          ... "
    if grep -q "ghcr.io/teableio/teable" "$deployment_file"; then
        printf "${GREEN}✓${NC}\n"
    else
        printf "${RED}✗${NC}\n"
        deployment_issues=$((deployment_issues + 1))
    fi

    printf "  Health checks                 ... "
    if grep -q "livenessProbe:" "$deployment_file" && grep -q "readinessProbe:" "$deployment_file"; then
        printf "${GREEN}✓${NC}\n"
    else
        printf "${RED}✗${NC}\n"
        deployment_issues=$((deployment_issues + 1))
    fi

    printf "  Resource limits               ... "
    if grep -q "resources:" "$deployment_file" && grep -q "limits:" "$deployment_file"; then
        printf "${GREEN}✓${NC}\n"
    else
        printf "${RED}✗${NC}\n"
        deployment_issues=$((deployment_issues + 1))
    fi

    printf "  Environment variables         ... "
    if grep -q "envFrom:" "$deployment_file"; then
        printf "${GREEN}✓${NC}\n"
    else
        printf "${RED}✗${NC}\n"
        deployment_issues=$((deployment_issues + 1))
    fi

    if [ $deployment_issues -eq 0 ]; then
        print_success "Deployment configuration is valid"
        return 0
    else
        print_error "$deployment_issues deployment issues found"
        return 1
    fi
}

# Function to check install scripts
check_install_scripts() {
    print_header "Checking Installation Scripts"

    local manifests_dir="k8s-manifests"
    local install_script="$manifests_dir/install.sh"
    local uninstall_script="$manifests_dir/uninstall.sh"

    local script_issues=0

    printf "  Install script exists         ... "
    if [ -f "$install_script" ]; then
        printf "${GREEN}✓${NC}\n"
    else
        printf "${RED}✗${NC}\n"
        script_issues=$((script_issues + 1))
    fi

    printf "  Install script executable     ... "
    if [ -x "$install_script" ]; then
        printf "${GREEN}✓${NC}\n"
    else
        printf "${RED}✗${NC}\n"
        script_issues=$((script_issues + 1))
    fi

    printf "  Uninstall script exists       ... "
    if [ -f "$uninstall_script" ]; then
        printf "${GREEN}✓${NC}\n"
    else
        printf "${RED}✗${NC}\n"
        script_issues=$((script_issues + 1))
    fi

    printf "  Uninstall script executable   ... "
    if [ -x "$uninstall_script" ]; then
        printf "${GREEN}✓${NC}\n"
    else
        printf "${RED}✗${NC}\n"
        script_issues=$((script_issues + 1))
    fi

    if [ $script_issues -eq 0 ]; then
        print_success "Installation scripts are ready"
        return 0
    else
        print_error "$script_issues script issues found"
        return 1
    fi
}

# Function to show summary
show_summary() {
    print_header "Verification Summary"

    local total_files=$(find k8s-manifests -type f 2>/dev/null | wc -l)
    local yaml_files=$(find k8s-manifests -name "*.yaml" 2>/dev/null | wc -l)

    print_status "Total files generated: $total_files"
    print_status "YAML manifest files: $yaml_files"

    echo ""
    print_status "Ready for deployment commands:"
    echo "  cd k8s-manifests"
    echo "  ./install.sh              # Install with kubectl"
    echo ""
    print_status "Alternative deployment methods:"
    echo "  kubectl apply -f k8s-manifests/    # Direct kubectl"
    echo "  ./install-fixed.sh --use-static    # Using wrapper script"
    echo ""
    print_status "Access after deployment:"
    echo "  kubectl port-forward svc/teable 8080:3000 -n teable"
    echo "  Visit: http://localhost:8080"
}

# Function to show usage
show_usage() {
    cat << EOF
Teable Kubernetes Manifests Verification Script

Usage: $0 [OPTIONS]

Options:
    --generate      Generate manifests before verification
    --verbose       Show verbose output
    -h, --help      Show this help message

Examples:
    $0                    # Verify existing manifests
    $0 --generate         # Generate then verify manifests
    $0 --verbose          # Show detailed verification info

This script verifies:
- Manifest files exist and are complete
- YAML syntax is valid
- Kubernetes resource structure is correct
- Configuration values are present
- Deployment configuration is valid
- Installation scripts are ready

EOF
}

# Parse command line arguments
GENERATE_FIRST=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --generate)
            GENERATE_FIRST=true
            shift
            ;;
        --verbose)
            VERBOSE=true
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

# Main verification function
main() {
    echo "🔍 Teable Kubernetes Manifests Verification"
    echo "============================================"
    echo ""

    # Generate manifests if requested
    if [ "$GENERATE_FIRST" = true ]; then
        print_status "Generating manifests first..."
        if [ -f "./generate-k8s.sh" ]; then
            ./generate-k8s.sh
        else
            print_error "generate-k8s.sh not found"
            exit 1
        fi
        echo ""
    fi

    local total_errors=0

    # Run all verification checks
    if ! check_manifests_directory; then
        total_errors=$((total_errors + 1))
    fi

    if ! check_required_files; then
        total_errors=$((total_errors + 1))
    fi

    if ! validate_yaml_files; then
        total_errors=$((total_errors + 1))
    fi

    if ! check_k8s_resources; then
        total_errors=$((total_errors + 1))
    fi

    if ! check_configuration; then
        total_errors=$((total_errors + 1))
    fi

    if ! check_deployment; then
        total_errors=$((total_errors + 1))
    fi

    if ! check_install_scripts; then
        total_errors=$((total_errors + 1))
    fi

    # Show results
    print_header "Verification Results"

    if [ $total_errors -eq 0 ]; then
        print_success "✅ ALL VERIFICATIONS PASSED!"
        print_success "Your Teable Kubernetes manifests are ready for deployment!"
        show_summary
        exit 0
    else
        print_error "❌ $total_errors verification(s) failed"
        print_status "Please review the errors above and regenerate manifests if needed"
        print_status "Try running: ./generate-k8s.sh"
        exit 1
    fi
}

# Run main function
main "$@"
