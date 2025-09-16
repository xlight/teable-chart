#!/bin/bash

echo "====================================="
echo "🚀 Teable Interactive Installer"
echo "====================================="
echo ""

# Function to ask yes/no questions
ask_yes_no() {
    local question="$1"
    local default="$2"

    if [[ "$default" == "y" ]]; then
        echo -n "$question [Y/n]: "
    else
        echo -n "$question [y/N]: "
    fi

    read -r response
    response=${response:-$default}

    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to ask questions
ask() {
    local question="$1"
    local default="$2"
    if [[ -n "$default" ]]; then
        echo -n "$question [$default]: "
    else
        echo -n "$question: "
    fi
    read -r response
    echo "${response:-$default}"
}

# Configuration
echo "1. Basic Configuration"
echo "-----------------------"
NAMESPACE=$(ask "Enter Kubernetes namespace" "teable")
PUBLIC_ORIGIN=$(ask "Enter public origin URL" "http://localhost:8080")

echo ""
echo "2. Deployment Mode"
echo "  1) embedded - Use embedded PostgreSQL, Redis, MinIO"
echo "  2) external - Use external services only"
echo "  3) mixed - Mix embedded and external services"
echo -n "Select mode (1-3) [1]: "
read -r MODE
MODE=${MODE:-1}

if [[ "$MODE" == "2" ]] || [[ "$MODE" == "3" ]]; then
    echo ""
    echo "3. External Services Configuration"

    if [[ "$MODE" == "2" ]] || ask_yes_no "Configure external PostgreSQL?" "n"; then
        EXTERNAL_DB_URL=$(ask "PostgreSQL URL" "postgresql://user:pass@host:port/db")
    fi

    if [[ "$MODE" == "2" ]] || ask_yes_no "Configure external Redis?" "n"; then
        EXTERNAL_REDIS_URI=$(ask "Redis URI" "redis://host:port/db")
    fi

    if [[ "$MODE" == "2" ]] || ask_yes_no "Configure external MinIO?" "n"; then
        EXTERNAL_MINIO_ENDPOINT=$(ask "MinIO endpoint" "https://minio.example.com")
        EXTERNAL_MINIO_ACCESS_KEY=$(ask "MinIO access key" "minioadmin")
        EXTERNAL_MINIO_SECRET_KEY=$(ask "MinIO secret key" "minioadmin123")
    fi
fi

echo ""
echo "Configuration Summary:"
echo "  Namespace: $NAMESPACE"
echo "  Public Origin: $PUBLIC_ORIGIN"
echo "  Mode: $MODE"
if [[ -n "$EXTERNAL_DB_URL" ]]; then
    echo "  Database: External PostgreSQL"
else
    echo "  Database: Embedded PostgreSQL"
fi

echo ""
echo -n "Proceed with installation? [Y/n]: "
read -r CONFIRM
CONFIRM=${CONFIRM:-y}

if [[ "$CONFIRM" == "y" ]] || [[ "$CONFIRM" == "Y" ]]; then
    echo "✅ Starting installation..."

    # Install with appropriate configuration
    if [[ -n "$EXTERNAL_DB_URL" ]] || [[ -n "$EXTERNAL_REDIS_URI" ]] || [[ -n "$EXTERNAL_MINIO_ENDPOINT" ]]; then
        helm install teable ./teable-helm \
          --namespace "$NAMESPACE" \
          --create-namespace \
          --set postgresql.enabled=false \
          --set redis.enabled=false \
          --set minio.enabled=false \
          --set database.url="$EXTERNAL_DB_URL" \
          --set cache.redisUri="$EXTERNAL_REDIS_URI" \
          --set storage.minio.endpoint="$EXTERNAL_MINIO_ENDPOINT" \
          --set storage.minio.accessKey="$EXTERNAL_MINIO_ACCESS_KEY" \
          --set storage.minio.secretKey="$EXTERNAL_MINIO_SECRET_KEY" \
          --set teable.publicOrigin="$PUBLIC_ORIGIN"
    else
        helm install teable ./teable-helm --namespace "$NAMESPACE" --create-namespace
    fi

    echo ""
    echo "🎉 Installation completed!"
    echo ""
    echo "📋 Post-installation access:"
    echo ""
    echo "Access Teable:"
    echo "  kubectl port-forward svc/teable 8080:3000 -n $NAMESPACE"
    echo "  Visit: http://localhost:8080"
    echo ""

    echo "Check status:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  kubectl get svc -n $NAMESPACE"
    echo ""

    echo "View logs:"
    echo "  kubectl logs -l app=teable -n $NAMESPACE -f"

else
    echo "Installation cancelled."
fi
