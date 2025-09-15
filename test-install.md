# Teable Test Installation Guide

This guide helps you test the Teable Helm chart installation without external dependencies.

## Quick Test (Standalone Mode)

Since the Helm chart currently doesn't include automatic dependency management, you can test with a standalone configuration that assumes external services.

### 1. Basic Installation Test

```bash
# Install without dependencies (default now)
./install.sh

# Or manually with Helm
helm install teable ./teable-helm --namespace teable --create-namespace
```

This will:
- Install only the Teable application
- Use external service endpoints (you'll need to configure these)
- Skip PostgreSQL, Redis, and MinIO dependencies

### 2. Check Installation Status

```bash
# Check if pods are running
kubectl get pods -n teable

# Check services
kubectl get svc -n teable

# View logs
kubectl logs -l app.kubernetes.io/name=teable -n teable
```

### 3. Expected Behavior

**Initial Status**: The Teable pod will likely show `CrashLoopBackOff` or `Error` because it can't connect to the external services (PostgreSQL, Redis, MinIO) that aren't configured yet.

This is **expected** and **normal** for this test installation.

## Testing with Docker Compose (Recommended)

For a complete working test, use Docker Compose to set up the dependencies first:

### 1. Create docker-compose.yml

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15.4
    environment:
      POSTGRES_DB: teable
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7.2.4
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data

volumes:
  postgres_data:
  redis_data:
  minio_data:
```

### 2. Start Dependencies

```bash
# Start services
docker-compose up -d

# Create MinIO buckets
docker exec -i $(docker-compose ps -q minio) mc alias set local http://localhost:9000 minioadmin minioadmin
docker exec -i $(docker-compose ps -q minio) mc mb local/teable-pub
docker exec -i $(docker-compose ps -q minio) mc mb local/teable-pvt
docker exec -i $(docker-compose ps -q minio) mc anonymous set public local/teable-pub
```

### 3. Update Kubernetes Services

Create external services to point to your Docker containers:

```bash
# Get your Docker host IP (usually Docker Desktop uses host.docker.internal)
# For Linux, use your actual IP address

# Create external services
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: external-postgres
  namespace: teable
spec:
  type: ExternalName
  externalName: host.docker.internal
  ports:
  - port: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: external-redis
  namespace: teable
spec:
  type: ExternalName
  externalName: host.docker.internal
  ports:
  - port: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: external-minio
  namespace: teable
spec:
  type: ExternalName
  externalName: host.docker.internal
  ports:
  - port: 9000
EOF
```

### 4. Install with Correct Configuration

Create a test values file:

```yaml
# test-values.yaml
teable:
  publicOrigin: "http://localhost:8080"
  jwtSecret: "test-jwt-secret-change-in-production"
  sessionSecret: "test-session-secret-change-in-production"

database:
  url: "postgresql://postgres:password@external-postgres:5432/teable"

cache:
  redisUri: "redis://external-redis:6379/0"

storage:
  minio:
    endpoint: "localhost:9000"
    internalEndpoint: "external-minio"
    port: "9000"
    internalPort: "9000"
    useSSL: "false"
    accessKey: "minioadmin"
    secretKey: "minioadmin"
  prefix: "http://localhost:9000"

ingress:
  enabled: false

service:
  type: NodePort
```

Install with test configuration:

```bash
helm upgrade --install teable ./teable-helm \
  --namespace teable \
  --create-namespace \
  --values test-values.yaml
```

### 5. Access the Application

```bash
# Port forward to access the application
kubectl port-forward svc/teable 8080:3000 -n teable

# Access at http://localhost:8080
```

## Verification Steps

1. **Check Pod Status**:
   ```bash
   kubectl get pods -n teable
   # Should show Running status
   ```

2. **Check Logs**:
   ```bash
   # Check migration logs
   kubectl logs -l app.kubernetes.io/name=teable -c db-migrate -n teable
   
   # Check application logs
   kubectl logs -l app.kubernetes.io/name=teable -n teable
   ```

3. **Test Health Endpoint**:
   ```bash
   kubectl exec -it deployment/teable -n teable -- curl http://localhost:3000/health
   ```

4. **Access Web Interface**:
   - Open http://localhost:8080 in your browser
   - You should see the Teable interface

## Troubleshooting

### Common Issues

1. **Pod CrashLoopBackOff**:
   - Check if external services are running
   - Verify connection strings in configuration
   - Check logs: `kubectl logs -l app.kubernetes.io/name=teable -n teable`

2. **Database Connection Failed**:
   - Ensure PostgreSQL is accessible from Kubernetes
   - Check if database `teable` exists
   - Verify credentials

3. **MinIO Connection Issues**:
   - Ensure buckets `teable-pub` and `teable-pvt` exist
   - Check MinIO credentials
   - Verify bucket permissions (public bucket should be publicly readable)

4. **Redis Connection Failed**:
   - Ensure Redis is accessible
   - Check Redis URI format

### Debug Commands

```bash
# Get detailed pod information
kubectl describe pod -l app.kubernetes.io/name=teable -n teable

# Check all resources
kubectl get all -n teable

# Check configmap and secrets
kubectl describe configmap teable-config -n teable
kubectl describe secret teable-secret -n teable

# Network debugging
kubectl exec -it deployment/teable -n teable -- nslookup external-postgres
kubectl exec -it deployment/teable -n teable -- telnet external-postgres 5432
```

## Cleanup

```bash
# Remove Kubernetes resources
helm uninstall teable -n teable
kubectl delete namespace teable

# Stop Docker services
docker-compose down -v
```

## Next Steps

Once you've verified the basic installation works:

1. Set up proper external services (managed PostgreSQL, Redis, MinIO)
2. Configure production values with proper secrets
3. Set up ingress with TLS certificates
4. Configure monitoring and backup strategies

This test installation validates that the Helm chart templates are correct and the application can start with proper external dependencies.