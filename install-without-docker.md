# Teable Installation Without Docker

This guide helps you install Teable on Kubernetes when Docker is not available on your system.

## Overview

Since Docker is not available, we'll install Teable assuming you have external PostgreSQL, Redis, and MinIO services already configured, or you'll need to set them up separately.

## Prerequisites

- Kubernetes cluster with kubectl access
- External PostgreSQL database (version 12+)
- External Redis service (version 5+)
- External MinIO or S3-compatible storage
- kubectl command-line tool

## Quick Installation

### 1. Generate Kubernetes Manifests

```bash
# Basic installation with default external service endpoints
./generate-k8s.sh

# Or with custom configuration
./generate-k8s.sh \
  --public-origin "https://your-domain.com" \
  --database-url "postgresql://user:password@your-db-host:5432/teable" \
  --redis-uri "redis://your-redis-host:6379/0" \
  --minio-endpoint "your-minio-host:9000" \
  --minio-access-key "your-access-key" \
  --minio-secret-key "your-secret-key"
```

### 2. Configure External Services

Edit the generated configuration files to match your external services:

```bash
# Edit the secret file with your actual service endpoints
vim k8s-manifests/secret.yaml
```

Update these values in `secret.yaml`:
- `PRISMA_DATABASE_URL`: Your PostgreSQL connection string
- `BACKEND_CACHE_REDIS_URI`: Your Redis connection URI
- `BACKEND_STORAGE_MINIO_ACCESS_KEY`: MinIO access key
- `BACKEND_STORAGE_MINIO_SECRET_KEY`: MinIO secret key

Edit the ConfigMap for public endpoints:

```bash
# Edit the configmap file
vim k8s-manifests/configmap.yaml
```

Update these values in `configmap.yaml`:
- `PUBLIC_ORIGIN`: Your public domain
- `BACKEND_STORAGE_MINIO_ENDPOINT`: Public MinIO endpoint
- `STORAGE_PREFIX`: Storage URL prefix
- `BACKEND_STORAGE_MINIO_INTERNAL_ENDPOINT`: Internal MinIO endpoint

### 3. Install Teable

```bash
cd k8s-manifests
./install.sh
```

### 4. Verify Installation

```bash
# Check pod status
kubectl get pods -n teable

# View logs
kubectl logs -l app.kubernetes.io/name=teable -n teable

# Check if health endpoint responds
kubectl exec -it deployment/teable -n teable -- curl http://localhost:3000/health
```

### 5. Access Application

```bash
# Port forward to access locally
kubectl port-forward svc/teable 8080:3000 -n teable

# Access at http://localhost:8080
```

## External Service Configuration Examples

### PostgreSQL Database

You need a PostgreSQL database with:
- Database name: `teable`
- User with full permissions on the database
- PostgreSQL version 12 or higher

Example connection string:
```
postgresql://teable_user:secure_password@postgres.example.com:5432/teable
```

### Redis Cache

You need a Redis instance:
- Redis version 5 or higher
- No authentication required (or with password)

Example connection string:
```
redis://redis.example.com:6379/0
# With password:
redis://:password@redis.example.com:6379/0
```

### MinIO/S3 Storage

You need MinIO or S3-compatible storage with:
- Two buckets: `teable-pub` (public) and `teable-pvt` (private)
- Access key and secret key
- Public bucket must have public read permissions

Example configuration:
```yaml
BACKEND_STORAGE_MINIO_ENDPOINT: "minio.example.com"
BACKEND_STORAGE_MINIO_ACCESS_KEY: "your-access-key"
BACKEND_STORAGE_MINIO_SECRET_KEY: "your-secret-key"
STORAGE_PREFIX: "https://minio.example.com"
```

## Alternative: Using Cloud Services

### AWS RDS + ElastiCache + S3

```bash
./generate-k8s.sh \
  --database-url "postgresql://user:pass@your-rds-instance.amazonaws.com:5432/teable" \
  --redis-uri "redis://your-elasticache-cluster.cache.amazonaws.com:6379/0" \
  --minio-endpoint "s3.amazonaws.com" \
  --minio-access-key "your-aws-access-key" \
  --minio-secret-key "your-aws-secret-key"
```

### Google Cloud SQL + Memorystore + Cloud Storage

```bash
./generate-k8s.sh \
  --database-url "postgresql://user:pass@your-cloud-sql-ip:5432/teable" \
  --redis-uri "redis://your-memorystore-ip:6379/0" \
  --minio-endpoint "storage.googleapis.com" \
  --minio-access-key "your-gcp-access-key" \
  --minio-secret-key "your-gcp-secret-key"
```

## Troubleshooting Without Docker

### Cannot Connect to External Services

1. **Check network connectivity**:
   ```bash
   # From within the pod
   kubectl exec -it deployment/teable -n teable -- nslookup your-db-host
   kubectl exec -it deployment/teable -n teable -- telnet your-db-host 5432
   ```

2. **Verify service URLs**:
   ```bash
   # Check if services are accessible from your cluster
   kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup your-db-host
   ```

3. **Review connection strings**:
   ```bash
   # Check the actual values in your secret
   kubectl get secret teable-secret -n teable -o yaml
   ```

### Database Migration Issues

1. **Check database permissions**:
   - Ensure the database user has CREATE, ALTER, DROP permissions
   - Verify the database `teable` exists

2. **View migration logs**:
   ```bash
   kubectl logs -l app.kubernetes.io/name=teable -c db-migrate -n teable
   ```

### Storage Issues

1. **Verify MinIO/S3 buckets**:
   - Ensure buckets `teable-pub` and `teable-pvt` exist
   - Check that `teable-pub` has public read permissions

2. **Test storage connectivity**:
   ```bash
   # From within the pod
   kubectl exec -it deployment/teable -n teable -- curl -I http://your-minio-host:9000/minio/health/live
   ```

## Production Considerations

### Security
- Use TLS/SSL for all database connections
- Enable Redis AUTH if possible
- Use HTTPS for MinIO endpoints
- Store secrets securely (consider using Kubernetes secrets or external secret management)

### High Availability
- Use managed database services with replication
- Set up Redis clustering or managed Redis service
- Use object storage with high availability (S3, Google Cloud Storage, etc.)
- Configure multiple Teable replicas

### Performance
- Size your database appropriately
- Configure Redis with sufficient memory
- Use CDN for static assets from object storage
- Set appropriate resource limits for Teable pods

## Alternative Installation Methods

If you can't use the generated manifests, you can also:

1. **Use the original manual YAML files** from the readme.md
2. **Deploy using Helm** (if Helm is available):
   ```bash
   ./simple-install.sh
   ```
3. **Use the advanced installation script**:
   ```bash
   ./install.sh --skip-dependencies
   ```

## Getting Help

- Check the main installation guide: `INSTALLATION-GUIDE.md`
- Run the status checker: `./check-status.sh`
- Review logs: `kubectl logs -l app.kubernetes.io/name=teable -n teable`
- Check external service connectivity from within the cluster

This approach allows you to run Teable without Docker by leveraging external managed services or separately configured infrastructure.