# Teable Kubernetes Quick Start Guide

This guide helps you quickly deploy Teable on Kubernetes using the provided Helm chart.

## Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.0+
- kubectl configured
- 4GB+ available memory
- 2+ CPU cores

## Quick Installation

### 1. Clone and Setup

```bash
# Navigate to the teable installation directory
cd teable_install

# Make the installation script executable
chmod +x install.sh
```

### 2. Test Template Generation (Recommended First Step)

Before installing, test that templates generate correctly:

```bash
# Test template generation
./test-templates.sh

# This validates templates without requiring external services
```

### 3. Development Installation (Standalone Mode)

The current chart is configured for standalone mode (external services):

```bash
# Install with default settings (external services required)
./install.sh

# Or manually with Helm
helm install teable ./teable-helm --create-namespace --namespace teable
```

**Note**: This installs only the Teable application. External PostgreSQL, Redis, and MinIO are required.

### 4. Set Up External Dependencies (Required)

Since the chart uses external services, set them up first:

```bash
# Start dependencies with Docker Compose
docker-compose up -d

# Wait for services to be ready
docker-compose ps

# Access MinIO console to verify buckets
open http://localhost:9001
# Login: minioadmin / minioadmin
```

### 5. Access Your Installation

After dependencies are running:

```bash
# Use port-forward to access Teable
kubectl port-forward svc/teable 8080:3000 -n teable
# Then visit: http://localhost:8080
```

### 6. Production Installation

For production with external managed services:

```bash
# Create custom values file
cp teable-helm/values-prod.yaml my-production-values.yaml

# Edit the file and update:
# - teable.publicOrigin: "https://your-domain.com"
# - teable.jwtSecret: "your-secure-64-char-jwt-secret"
# - teable.sessionSecret: "your-secure-64-char-session-secret"
# - database.url: "postgresql://user:pass@your-db:5432/teable"
# - cache.redisUri: "redis://your-redis:6379/0"
# - storage.minio endpoints and credentials

# Install with production settings
./install.sh -e production -f my-production-values.yaml -n teable-prod -r teable-prod
```

## Common Configurations

### Configure External Services

The chart is preconfigured for external services. Update these in your values file:

```yaml
# Database configuration
database:
  url: "postgresql://postgres:password@host.docker.internal:5432/teable"

# Redis configuration  
cache:
  redisUri: "redis://host.docker.internal:6379/0"

# MinIO configuration
storage:
  minio:
    endpoint: "localhost:9000"
    internalEndpoint: "host.docker.internal"
    port: "9000"
    internalPort: "9000"
    useSSL: "false"
    accessKey: "minioadmin"
    secretKey: "minioadmin"
  prefix: "http://localhost:9000"
```

### Enable Ingress (Optional)

```yaml
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: teable.local
      paths:
        - path: /
          pathType: Prefix
```

## Verification

Check if everything is running:

```bash
# Check pods status
kubectl get pods -n teable

# Check services
kubectl get svc -n teable

# View logs
kubectl logs -l app.kubernetes.io/name=teable -n teable -f

# Test health endpoint
kubectl exec -it deployment/teable -n teable -- curl localhost:3000/health
```

## Troubleshooting

### Application Won't Start

1. Check init container logs (database migration):
```bash
kubectl logs -l app.kubernetes.io/name=teable -c db-migrate -n teable
```

2. Check main application logs:
```bash
kubectl logs -l app.kubernetes.io/name=teable -n teable
```

### Database Connection Issues

1. Verify database is running:
```bash
kubectl get pods -l app.kubernetes.io/name=postgresql -n teable
```

2. Test database connection:
```bash
kubectl exec -it deployment/teable -n teable -- env | grep PRISMA_DATABASE_URL
```

### Storage Issues

1. Check MinIO status:
```bash
kubectl get pods -l app.kubernetes.io/name=minio -n teable
```

2. Access MinIO console:
```bash
kubectl port-forward svc/teable-minio 9001:9001 -n teable
# Visit: http://localhost:9001 (admin/admin123 by default)
```

3. Verify buckets exist:
   - `teable-pub` (public bucket)
   - `teable-pvt` (private bucket)

## Cleanup

To completely remove the installation:

```bash
# Delete the Helm release
helm uninstall teable -n teable

# Delete the namespace (removes all resources)
kubectl delete namespace teable
```

## Next Steps

1. **Security**: Update default passwords and secrets
2. **Monitoring**: Set up monitoring and alerting
3. **Backup**: Configure database and storage backups
4. **Scaling**: Configure horizontal pod autoscaling
5. **SSL/TLS**: Set up proper certificates for HTTPS

## Support

- [Teable Documentation](https://docs.teable.io)
- [GitHub Issues](https://github.com/teableio/teable/issues)
- Check the `README.md` in the `teable-helm` directory for detailed configuration options

## Example Complete Workflow

```bash
# 1. Test templates first
./test-templates.sh

# 2. Start external dependencies
docker-compose up -d

# 3. Wait for services to be ready
sleep 30

# 4. Install Teable
./install.sh

# 5. Wait for pods to be ready (may take time due to external service connections)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=teable -n teable --timeout=300s

# 6. Access the application
kubectl port-forward svc/teable 8080:3000 -n teable &

# 7. Open browser to http://localhost:8080
echo "Teable is ready at http://localhost:8080"

# 8. When done, cleanup
helm uninstall teable -n teable
kubectl delete namespace teable
docker-compose down -v
```

That's it! You now have Teable running on Kubernetes. 🎉