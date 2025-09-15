# Teable Helm Chart

A Helm chart for deploying Teable, a modern collaborative database platform, on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- kubectl configured to communicate with your cluster

## Quick Start

1. Add the dependencies (if using external charts):
```bash
helm dependency update
```

2. Install with default values (includes PostgreSQL, Redis, and MinIO):
```bash
helm install teable ./teable-helm
```

3. Install with custom values:
```bash
helm install teable ./teable-helm -f custom-values.yaml
```

## Configuration

### Required Configuration

Before deploying to production, you **must** update the following values:

```yaml
teable:
  publicOrigin: "https://your-domain.com"
  jwtSecret: "your-secure-jwt-secret-64-chars-long"
  sessionSecret: "your-secure-session-secret-64-chars-long"

storage:
  minio:
    endpoint: "minio.your-domain.com"
    accessKey: "your-minio-access-key"
    secretKey: "your-minio-secret-key"
  prefix: "https://minio.your-domain.com"
```

### Values File Structure

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of Teable replicas | `1` |
| `image.repository` | Teable image repository | `ghcr.io/teableio/teable` |
| `image.tag` | Teable image tag | `latest` |
| `teable.publicOrigin` | Public URL for Teable | `https://teable.local` |
| `teable.jwtSecret` | JWT secret key | `your-jwt-secret-please-change-this` |
| `teable.sessionSecret` | Session secret key | `your-session-secret-please-change-this` |
| `storage.provider` | Storage provider | `minio` |
| `storage.publicBucket` | Public storage bucket name | `teable-pub` |
| `storage.privateBucket` | Private storage bucket name | `teable-pvt` |
| `postgres.enabled` | Enable internal PostgreSQL | `true` |
| `redis.enabled` | Enable internal Redis | `true` |
| `minio.enabled` | Enable internal MinIO | `true` |

## Deployment Scenarios

### 1. Development (All Internal Services)

```bash
helm install teable ./teable-helm \
  --set teable.publicOrigin=https://teable.local \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=teable.local
```

### 2. Production (External Services)

```bash
helm install teable ./teable-helm -f values-prod.yaml \
  --set postgres.enabled=false \
  --set redis.enabled=false \
  --set database.url="postgresql://user:pass@external-db:5432/teable" \
  --set cache.redisUri="redis://external-redis:6379/0"
```

### 3. Staging with Internal MinIO

```bash
helm install teable ./teable-helm \
  --set replicaCount=2 \
  --set postgres.enabled=false \
  --set redis.enabled=false \
  --set minio.enabled=true \
  --set database.url="postgresql://user:pass@staging-db:5432/teable"
```

## External Dependencies

When using external services, ensure the following:

### PostgreSQL
- Version 12+ required
- Database `teable` must exist
- User must have admin privileges
- Connection string format: `postgresql://user:pass@host:port/database`

### Redis
- Version 5+ required
- Used for both caching and queues
- Connection string format: `redis://user:pass@host:port/db`

### MinIO/S3
- Two buckets required:
  - Public bucket with public read permissions
  - Private bucket with default permissions
- Endpoint must be accessible by end users
- HTTPS required if Teable uses HTTPS

## Ingress Configuration

### Nginx Ingress Example

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "128k"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
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

## MinIO Bucket Setup

The MinIO buckets need proper configuration:

1. **Public Bucket** (`teable-pub`):
   - Must have public read permissions
   - Used for user-uploaded files that need public access

2. **Private Bucket** (`teable-pvt`):
   - Default permissions (private)
   - Used for internal application data

### Manual Bucket Creation

If using external MinIO/S3:

```bash
# Create buckets
mc mb minio/teable-pub
mc mb minio/teable-pvt

# Set public read policy for public bucket
mc anonymous set public minio/teable-pub
```

## Monitoring and Health Checks

The chart includes comprehensive health checks:

- **Startup Probe**: Ensures the application starts properly
- **Liveness Probe**: Restarts unhealthy containers
- **Readiness Probe**: Controls traffic routing

Health check endpoint: `GET /health`

## Troubleshooting

### Common Issues

1. **Database Migration Fails**
   ```bash
   kubectl logs -l app.kubernetes.io/name=teable -c db-migrate
   ```

2. **Application Won't Start**
   ```bash
   kubectl describe pod -l app.kubernetes.io/name=teable
   kubectl logs -l app.kubernetes.io/name=teable
   ```

3. **Storage Connection Issues**
   - Verify MinIO credentials and endpoint accessibility
   - Check bucket permissions
   - Ensure HTTPS/HTTP configuration matches

4. **Database Connection Issues**
   - Verify database URL format
   - Check database user permissions
   - Ensure database exists

### Useful Commands

```bash
# Check all resources
kubectl get all -l app.kubernetes.io/instance=teable

# View application logs
kubectl logs -l app.kubernetes.io/name=teable -f

# Check configuration
kubectl describe configmap teable-config
kubectl describe secret teable-secret

# Test database connection
kubectl exec -it deployment/teable -- psql $PRISMA_DATABASE_URL

# Test application health
kubectl exec -it deployment/teable -- curl localhost:3000/health
```

## Security Considerations

### Production Checklist

- [ ] Change default JWT and session secrets
- [ ] Use strong MinIO credentials
- [ ] Enable TLS/SSL for all services
- [ ] Configure proper network policies
- [ ] Set up monitoring and alerting
- [ ] Regular backup strategy
- [ ] Update container images regularly

### Network Security

```yaml
# Example NetworkPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: teable-network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: teable
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
    - protocol: TCP
      port: 6379  # Redis
    - protocol: TCP
      port: 9000  # MinIO
```

## Upgrading

### Helm Upgrade

```bash
# Upgrade with new values
helm upgrade teable ./teable-helm -f new-values.yaml

# Upgrade to new chart version
helm upgrade teable ./teable-helm --version 0.2.0
```

### Database Migrations

Database migrations are handled automatically by the init container. The main application container uses `skip-migrate` to avoid running migrations twice.

## Contributing

1. Test your changes with `helm template` and `helm lint`
2. Update this README if adding new features
3. Follow Helm best practices
4. Test with both internal and external dependencies

## Support

- [Teable Documentation](https://docs.teable.io)
- [Teable GitHub Issues](https://github.com/teableio/teable/issues)
- [Helm Chart Issues](https://github.com/teableio/teable/issues)

## License

This Helm chart is licensed under the same license as Teable.