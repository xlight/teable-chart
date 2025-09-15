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

### 2. Development Installation (All-in-One)

For testing and development with all services included:

```bash
# Install with default settings
./install.sh

# Or manually with Helm
helm install teable ./teable-helm --create-namespace --namespace teable
```

This installs:
- Teable application
- PostgreSQL database
- Redis cache
- MinIO object storage
- All in the `teable` namespace

### 3. Access Your Installation

After installation, get the access URL:

```bash
# If using ingress (update /etc/hosts to point teable.local to your cluster IP)
echo "127.0.0.1 teable.local" | sudo tee -a /etc/hosts

# Or use port-forward
kubectl port-forward svc/teable 8080:3000 -n teable
# Then visit: http://localhost:8080
```

### 4. Production Installation

For production deployment:

```bash
# Create custom values file
cp teable-helm/values-prod.yaml my-production-values.yaml

# Edit the file and update:
# - teable.publicOrigin: "https://your-domain.com"
# - teable.jwtSecret: "your-secure-64-char-jwt-secret"
# - teable.sessionSecret: "your-secure-64-char-session-secret"
# - storage.minio.endpoint: "minio.your-domain.com"
# - storage.minio.accessKey: "your-minio-access-key"
# - storage.minio.secretKey: "your-minio-secret-key"

# Install with production settings
./install.sh -e production -f my-production-values.yaml -n teable-prod -r teable-prod
```

## Common Configurations

### Enable Ingress

```yaml
# Add to your values file
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: teable.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: teable-tls
      hosts:
        - teable.yourdomain.com
```

### Use External Database

```yaml
# Disable internal PostgreSQL
postgres:
  enabled: false

# Configure external database
database:
  url: "postgresql://user:password@external-db:5432/teable"
```

### Use External Redis

```yaml
# Disable internal Redis
redis:
  enabled: false

# Configure external Redis (add to secret or values)
cache:
  redisUri: "redis://external-redis:6379/0"
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
# 1. Install for development
./install.sh

# 2. Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=teable -n teable --timeout=300s

# 3. Access the application
kubectl port-forward svc/teable 8080:3000 -n teable &

# 4. Open browser to http://localhost:8080
echo "Teable is ready at http://localhost:8080"

# 5. When done, cleanup
helm uninstall teable -n teable
kubectl delete namespace teable
```

That's it! You now have Teable running on Kubernetes. 🎉