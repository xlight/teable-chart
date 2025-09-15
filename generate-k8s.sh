#!/bin/bash

# Generate Static Kubernetes Manifests for Teable
# This script creates Kubernetes YAML files without requiring Helm

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
OUTPUT_DIR="./k8s-manifests"
PUBLIC_ORIGIN="http://localhost:8080"
JWT_SECRET="default-jwt-secret-change-in-production"
SESSION_SECRET="default-session-secret-change-in-production"
DATABASE_URL="postgresql://postgres:password@host.docker.internal:5432/teable"
REDIS_URI="redis://host.docker.internal:6379/0"
MINIO_ENDPOINT="localhost:9000"
MINIO_INTERNAL_ENDPOINT="host.docker.internal"
MINIO_ACCESS_KEY="minioadmin"
MINIO_SECRET_KEY="minioadmin"

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
Generate Static Kubernetes Manifests for Teable

Usage: $0 [OPTIONS]

Options:
    -n, --namespace NAMESPACE           Kubernetes namespace (default: teable)
    -r, --release RELEASE_NAME          Release name (default: teable)
    -o, --output OUTPUT_DIR             Output directory (default: ./k8s-manifests)
    --public-origin URL                 Public origin URL (default: http://localhost:8080)
    --database-url URL                  Database connection URL
    --redis-uri URI                     Redis connection URI
    --minio-endpoint ENDPOINT           MinIO endpoint
    --minio-access-key KEY              MinIO access key
    --minio-secret-key KEY              MinIO secret key
    -h, --help                          Show this help message

Examples:
    $0                                  # Generate with defaults
    $0 -n production -r teable-prod     # Generate for production
    $0 --public-origin https://teable.company.com

EOF
}

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
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --public-origin)
            PUBLIC_ORIGIN="$2"
            shift 2
            ;;
        --database-url)
            DATABASE_URL="$2"
            shift 2
            ;;
        --redis-uri)
            REDIS_URI="$2"
            shift 2
            ;;
        --minio-endpoint)
            MINIO_ENDPOINT="$2"
            shift 2
            ;;
        --minio-access-key)
            MINIO_ACCESS_KEY="$2"
            shift 2
            ;;
        --minio-secret-key)
            MINIO_SECRET_KEY="$2"
            shift 2
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

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate ConfigMap
print_status "Generating ConfigMap..."
cat > "$OUTPUT_DIR/configmap.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${RELEASE_NAME}-config
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: teable
    app.kubernetes.io/instance: ${RELEASE_NAME}
    app.kubernetes.io/version: "latest"
    app.kubernetes.io/managed-by: manual
data:
  # Application base configuration, public access domain
  PUBLIC_ORIGIN: "${PUBLIC_ORIGIN}"

  # Storage configuration
  BACKEND_STORAGE_PROVIDER: "minio"
  # Public endpoint, important! Must be accessible by end users
  BACKEND_STORAGE_MINIO_ENDPOINT: "${MINIO_ENDPOINT}"
  # Same as above but with protocol
  STORAGE_PREFIX: "http://${MINIO_ENDPOINT}"
  # Internal endpoint
  BACKEND_STORAGE_MINIO_INTERNAL_ENDPOINT: "${MINIO_INTERNAL_ENDPOINT}"
  # Public port, typically 443 or 9000
  BACKEND_STORAGE_MINIO_PORT: "9000"
  # Internal port, typically 80 or 9000
  BACKEND_STORAGE_MINIO_INTERNAL_PORT: "9000"
  # Enable HTTPS, note: if Teable uses HTTPS, MinIO must also use HTTPS to avoid CORS issues
  BACKEND_STORAGE_MINIO_USE_SSL: "false"

  # Cache configuration, fixed value
  BACKEND_CACHE_PROVIDER: "redis"

  # Other configurations, fixed values
  NEXT_ENV_IMAGES_ALL_REMOTE: "true"
  PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING: "1"
  NODE_TLS_REJECT_UNAUTHORIZED: "0"
EOF

# Generate Secret
print_status "Generating Secret..."
cat > "$OUTPUT_DIR/secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${RELEASE_NAME}-secret
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: teable
    app.kubernetes.io/instance: ${RELEASE_NAME}
    app.kubernetes.io/version: "latest"
    app.kubernetes.io/managed-by: manual
type: Opaque
stringData:
  # Database sensitive information
  PRISMA_DATABASE_URL: "${DATABASE_URL}"

  # Application secrets
  BACKEND_JWT_SECRET: "${JWT_SECRET}"
  BACKEND_SESSION_SECRET: "${SESSION_SECRET}"

  # MinIO authentication
  BACKEND_STORAGE_PUBLIC_BUCKET: "teable-pub"
  BACKEND_STORAGE_PRIVATE_BUCKET: "teable-pvt"
  BACKEND_STORAGE_MINIO_ACCESS_KEY: "${MINIO_ACCESS_KEY}"
  BACKEND_STORAGE_MINIO_SECRET_KEY: "${MINIO_SECRET_KEY}"

  # Redis authentication
  BACKEND_CACHE_REDIS_URI: "${REDIS_URI}"
EOF

# Generate ServiceAccount
print_status "Generating ServiceAccount..."
cat > "$OUTPUT_DIR/serviceaccount.yaml" << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${RELEASE_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: teable
    app.kubernetes.io/instance: ${RELEASE_NAME}
    app.kubernetes.io/version: "latest"
    app.kubernetes.io/managed-by: manual
EOF

# Generate Deployment
print_status "Generating Deployment..."
cat > "$OUTPUT_DIR/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${RELEASE_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: teable
    app.kubernetes.io/instance: ${RELEASE_NAME}
    app.kubernetes.io/version: "latest"
    app.kubernetes.io/managed-by: manual
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: teable
      app.kubernetes.io/instance: ${RELEASE_NAME}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: teable
        app.kubernetes.io/instance: ${RELEASE_NAME}
    spec:
      serviceAccountName: ${RELEASE_NAME}
      securityContext: {}
      # Add initContainers for database migration
      initContainers:
        - name: db-migrate
          securityContext: {}
          image: "ghcr.io/teableio/teable:latest"
          imagePullPolicy: IfNotPresent
          args:
            - migrate-only
          envFrom:
            - configMapRef:
                name: ${RELEASE_NAME}-config
            - secretRef:
                name: ${RELEASE_NAME}-secret
          resources:
            limits:
              cpu: 1000m
              memory: 1024Mi
            requests:
              cpu: 100m
              memory: 102Mi
      containers:
        - name: teable
          securityContext: {}
          image: "ghcr.io/teableio/teable:latest"
          imagePullPolicy: IfNotPresent
          args:
            - skip-migrate
          ports:
            - name: http
              containerPort: 3000
              protocol: TCP
          envFrom:
            - configMapRef:
                name: ${RELEASE_NAME}-config
            - secretRef:
                name: ${RELEASE_NAME}-secret
          startupProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 30
            successThreshold: 1
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 30
            timeoutSeconds: 5
            failureThreshold: 3
            successThreshold: 1
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 15
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
            successThreshold: 1
          resources:
            limits:
              cpu: 2000m
              memory: 4096Mi
            requests:
              cpu: 200m
              memory: 400Mi
EOF

# Generate Service
print_status "Generating Service..."
cat > "$OUTPUT_DIR/service.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: ${RELEASE_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: teable
    app.kubernetes.io/instance: ${RELEASE_NAME}
    app.kubernetes.io/version: "latest"
    app.kubernetes.io/managed-by: manual
spec:
  type: ClusterIP
  ports:
    - port: 3000
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: teable
    app.kubernetes.io/instance: ${RELEASE_NAME}
EOF

# Generate Ingress (optional)
print_status "Generating Ingress (optional)..."
cat > "$OUTPUT_DIR/ingress.yaml" << EOF
# Optional Ingress - uncomment and configure as needed
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: ${RELEASE_NAME}
#   namespace: ${NAMESPACE}
#   labels:
#     app.kubernetes.io/name: teable
#     app.kubernetes.io/instance: ${RELEASE_NAME}
#     app.kubernetes.io/version: "latest"
#     app.kubernetes.io/managed-by: manual
#   annotations:
#     kubernetes.io/ingress.class: nginx
#     nginx.ingress.kubernetes.io/proxy-body-size: "100m"
#     nginx.ingress.kubernetes.io/proxy-buffer-size: "128k"
#     nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
#     nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
#     nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
# spec:
#   rules:
#     - host: teable.local
#       http:
#         paths:
#           - path: /
#             pathType: Prefix
#             backend:
#               service:
#                 name: ${RELEASE_NAME}
#                 port:
#                   number: 3000
#   tls: []
#   #  - secretName: teable-tls
#   #    hosts:
#   #      - teable.local
EOF

# Generate namespace file
print_status "Generating Namespace..."
cat > "$OUTPUT_DIR/namespace.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    name: ${NAMESPACE}
    app.kubernetes.io/managed-by: manual
EOF

# Generate installation script
print_status "Generating installation script..."
cat > "$OUTPUT_DIR/install.sh" << 'EOF'
#!/bin/bash

# Install Teable using generated manifests

set -e

NAMESPACE="${1:-teable}"

echo "Installing Teable in namespace: $NAMESPACE"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Apply manifests in order
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

echo "Installation completed!"
echo ""
echo "To check status:"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "To access the application:"
echo "  kubectl port-forward svc/teable 8080:3000 -n $NAMESPACE"
echo "  Then visit: http://localhost:8080"
echo ""
echo "To view logs:"
echo "  kubectl logs -l app.kubernetes.io/name=teable -n $NAMESPACE"
EOF

chmod +x "$OUTPUT_DIR/install.sh"

# Generate uninstall script
print_status "Generating uninstall script..."
cat > "$OUTPUT_DIR/uninstall.sh" << 'EOF'
#!/bin/bash

# Uninstall Teable

set -e

NAMESPACE="${1:-teable}"

echo "Uninstalling Teable from namespace: $NAMESPACE"

# Delete resources in reverse order
echo "Deleting Deployment..."
kubectl delete -f deployment.yaml --ignore-not-found=true

echo "Deleting Service..."
kubectl delete -f service.yaml --ignore-not-found=true

echo "Deleting ServiceAccount..."
kubectl delete -f serviceaccount.yaml --ignore-not-found=true

echo "Deleting Secret..."
kubectl delete -f secret.yaml --ignore-not-found=true

echo "Deleting ConfigMap..."
kubectl delete -f configmap.yaml --ignore-not-found=true

echo "Deleting Namespace..."
kubectl delete -f namespace.yaml --ignore-not-found=true

echo "Uninstallation completed!"
EOF

chmod +x "$OUTPUT_DIR/uninstall.sh"

# Generate README
print_status "Generating README..."
cat > "$OUTPUT_DIR/README.md" << EOF
# Teable Kubernetes Manifests

This directory contains static Kubernetes manifests for deploying Teable.

## Generated Configuration

- **Namespace**: ${NAMESPACE}
- **Release Name**: ${RELEASE_NAME}
- **Public Origin**: ${PUBLIC_ORIGIN}
- **Database**: External PostgreSQL
- **Cache**: External Redis
- **Storage**: External MinIO

## Prerequisites

1. **External Services**: Ensure PostgreSQL, Redis, and MinIO are running and accessible
2. **kubectl**: Kubernetes command-line tool
3. **Cluster Access**: kubectl configured to access your cluster

## Quick Start

### 1. Start Dependencies (if using Docker Compose)

\`\`\`bash
# From the parent directory
docker-compose up -d
\`\`\`

### 2. Install Teable

\`\`\`bash
# Install with generated script
./install.sh

# Or manually apply manifests
kubectl apply -f .
\`\`\`

### 3. Access Application

\`\`\`bash
# Port forward to access locally
kubectl port-forward svc/${RELEASE_NAME} 8080:3000 -n ${NAMESPACE}

# Visit http://localhost:8080
\`\`\`

## Files Description

- \`namespace.yaml\`: Kubernetes namespace
- \`configmap.yaml\`: Non-sensitive configuration
- \`secret.yaml\`: Sensitive configuration (passwords, keys)
- \`serviceaccount.yaml\`: Service account for pods
- \`deployment.yaml\`: Main application deployment
- \`service.yaml\`: Kubernetes service
- \`ingress.yaml\`: Ingress configuration (commented out)
- \`install.sh\`: Installation script
- \`uninstall.sh\`: Uninstallation script

## Customization

To modify the configuration:

1. Edit the YAML files directly
2. Or regenerate with different parameters:
   \`\`\`bash
   # From parent directory
   ./generate-k8s.sh --public-origin https://your-domain.com --namespace production
   \`\`\`

## Troubleshooting

### Check Pod Status
\`\`\`bash
kubectl get pods -n ${NAMESPACE}
kubectl describe pods -l app.kubernetes.io/name=teable -n ${NAMESPACE}
\`\`\`

### View Logs
\`\`\`bash
# Application logs
kubectl logs -l app.kubernetes.io/name=teable -n ${NAMESPACE}

# Migration logs
kubectl logs -l app.kubernetes.io/name=teable -c db-migrate -n ${NAMESPACE}
\`\`\`

### Test Connectivity
\`\`\`bash
# Test health endpoint
kubectl exec -it deployment/${RELEASE_NAME} -n ${NAMESPACE} -- curl http://localhost:3000/health
\`\`\`

## Production Considerations

1. **Update Secrets**: Change JWT and session secrets in \`secret.yaml\`
2. **External Services**: Use managed PostgreSQL, Redis, and MinIO
3. **TLS/SSL**: Configure proper certificates
4. **Resources**: Adjust CPU and memory limits based on load
5. **Monitoring**: Set up monitoring and alerting
6. **Backup**: Configure backup strategy for data

EOF

print_success "Kubernetes manifests generated successfully!"
echo ""
print_status "Generated files in: $OUTPUT_DIR"
echo "Files created:"
find "$OUTPUT_DIR" -type f | sort | sed 's/^/  - /'
echo ""
print_status "To install:"
echo "  cd $OUTPUT_DIR"
echo "  ./install.sh"
echo ""
print_status "To access after installation:"
echo "  kubectl port-forward svc/$RELEASE_NAME 8080:3000 -n $NAMESPACE"
echo "  Open: http://localhost:8080"
