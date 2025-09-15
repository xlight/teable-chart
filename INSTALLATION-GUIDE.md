# Teable Kubernetes Installation Guide

This comprehensive guide provides multiple methods to install Teable on Kubernetes, from simple development setups to production deployments.

## 🚀 Quick Start (Recommended)

The fastest way to get Teable running:

### 1. Prerequisites
- Kubernetes cluster (1.19+)
- kubectl configured
- Docker (for dependencies)

### 2. Install External Dependencies
```bash
# Start PostgreSQL, Redis, and MinIO
docker-compose up -d

# Wait for services to start
sleep 30

# Verify services are running
docker-compose ps
```

### 3. Deploy Teable
```bash
# Generate and install Kubernetes manifests
./generate-k8s.sh
cd k8s-manifests
./install.sh

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=teable -n teable --timeout=300s
```

### 4. Access Application
```bash
# Port forward to access locally
kubectl port-forward svc/teable 8080:3000 -n teable

# Open browser to http://localhost:8080
```

**That's it!** 🎉 You now have Teable running on Kubernetes.

---

## 📋 Installation Methods Comparison

| Method | Complexity | Requirements | Best For |
|--------|------------|--------------|----------|
| **Static Manifests** | ⭐ Simple | kubectl only | Development, Testing |
| **Helm Chart** | ⭐⭐ Medium | kubectl + helm | Production, Customization |
| **Script Install** | ⭐ Simple | kubectl + helm | Quick deployment |

---

## 🛠️ Method 1: Static Kubernetes Manifests (Recommended)

**Pros**: No Helm required, simple, reliable
**Cons**: Less customizable

### Step-by-Step Installation

1. **Generate manifests**:
   ```bash
   ./generate-k8s.sh
   ```

2. **Review configuration** (optional):
   ```bash
   ls k8s-manifests/
   cat k8s-manifests/configmap.yaml
   ```

3. **Install**:
   ```bash
   cd k8s-manifests
   ./install.sh
   ```

4. **Verify installation**:
   ```bash
   kubectl get pods -n teable
   kubectl logs -l app.kubernetes.io/name=teable -n teable
   ```

### Customization Options

Generate with custom parameters:
```bash
./generate-k8s.sh \
  --namespace production \
  --release teable-prod \
  --public-origin https://teable.company.com \
  --database-url "postgresql://user:pass@prod-db:5432/teable"
```

---

## 🎯 Method 2: Helm Chart Installation

**Pros**: Highly customizable, production-ready
**Cons**: Requires Helm installation

### Prerequisites
```bash
# Install Helm (if not installed)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify Helm installation
helm version
```

### Installation Options

#### Option A: Simple Install (External Dependencies)
```bash
# Use the fixed installation script
./simple-install.sh

# Or manually with Helm
helm install teable ./teable-helm --namespace teable --create-namespace
```

#### Option B: Custom Values
```bash
# Create custom values file
cp teable-helm/values-standalone.yaml my-values.yaml

# Edit my-values.yaml with your configuration
vim my-values.yaml

# Install with custom values
helm install teable ./teable-helm \
  --namespace teable \
  --create-namespace \
  --values my-values.yaml
```

#### Option C: Production Installation
```bash
# Use production values
helm install teable ./teable-helm \
  --namespace teable-prod \
  --create-namespace \
  --values teable-helm/values-prod.yaml
```

### Helm Management Commands
```bash
# Check status
helm status teable -n teable

# Upgrade
helm upgrade teable ./teable-helm -n teable

# Rollback
helm rollback teable -n teable

# Uninstall
helm uninstall teable -n teable
```

---

## 🔧 Method 3: Script-Based Installation

**Pros**: Automated, handles common issues
**Cons**: Less control over process

### Available Scripts

#### Simple Installation Script
```bash
# Basic installation
./simple-install.sh

# With custom namespace
./simple-install.sh -n my-namespace

# Dry run to see what would be installed
./simple-install.sh --dry-run
```

#### Advanced Installation Script
```bash
# Full installation with dependency handling
./install.sh

# Skip dependency updates (recommended)
./install.sh --skip-dependencies

# Production environment
./install.sh -e production -f my-prod-values.yaml
```

---

## 🐳 External Dependencies Setup

Teable requires PostgreSQL, Redis, and MinIO. Here are setup options:

### Option 1: Docker Compose (Development)

```bash
# Start all dependencies
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs

# Stop all services
docker-compose down
```

**Services provided**:
- PostgreSQL on port 5432
- Redis on port 6379  
- MinIO on ports 9000 (API) and 9001 (Console)
- Adminer on port 8081 (optional database admin)

### Option 2: External Managed Services (Production)

Configure managed services in your values file:

```yaml
# Database configuration
database:
  url: "postgresql://user:password@your-managed-postgres:5432/teable"

# Redis configuration
cache:
  redisUri: "redis://your-managed-redis:6379/0"

# MinIO/S3 configuration
storage:
  minio:
    endpoint: "your-s3-endpoint.com"
    accessKey: "your-access-key"
    secretKey: "your-secret-key"
    useSSL: "true"
  prefix: "https://your-s3-endpoint.com"
```

### Option 3: In-Cluster Dependencies

**Note**: Currently disabled due to dependency issues. Working on fix.

---

## 🔍 Verification and Troubleshooting

### Health Checks

```bash
# Check pod status
kubectl get pods -n teable

# Check detailed pod information
kubectl describe pods -l app.kubernetes.io/name=teable -n teable

# Test health endpoint
kubectl exec -it deployment/teable -n teable -- curl http://localhost:3000/health
```

### Log Analysis

```bash
# View application logs
kubectl logs -l app.kubernetes.io/name=teable -n teable -f

# View migration logs (init container)
kubectl logs -l app.kubernetes.io/name=teable -c db-migrate -n teable

# View recent events
kubectl get events -n teable --sort-by='.lastTimestamp'
```

### Status Checking Script

```bash
# Comprehensive status check
./check-status.sh

# Check with detailed logs
./check-status.sh --logs

# Check specific namespace
./check-status.sh -n teable-prod
```

### Common Issues and Solutions

#### 1. Pod CrashLoopBackOff
**Cause**: Cannot connect to external services
**Solution**: 
- Verify external services are running: `docker-compose ps`
- Check connection strings in configuration
- Review pod logs: `kubectl logs -l app.kubernetes.io/name=teable -n teable`

#### 2. Database Migration Fails
**Cause**: Database not accessible or permissions issues
**Solution**:
- Check database URL format
- Verify database exists and user has permissions
- Review init container logs: `kubectl logs -l app.kubernetes.io/name=teable -c db-migrate -n teable`

#### 3. MinIO Connection Issues
**Cause**: Incorrect MinIO configuration or missing buckets
**Solution**:
- Verify MinIO is accessible: `curl http://localhost:9000/minio/health/live`
- Check if buckets exist: Access MinIO console at http://localhost:9001
- Verify access credentials

#### 4. Helm Template Errors
**Cause**: Chart template issues
**Solution**:
- Use static manifests instead: `./generate-k8s.sh`
- Validate YAML syntax: `./validate-yaml.sh`
- Check Helm version compatibility

---

## 🏭 Production Deployment Guide

### Pre-Production Checklist

- [ ] **External Services**: Set up managed PostgreSQL, Redis, and MinIO
- [ ] **Secrets**: Generate secure JWT and session secrets
- [ ] **Domain**: Configure proper domain and TLS certificates
- [ ] **Resources**: Size CPU and memory based on expected load
- [ ] **Monitoring**: Set up monitoring and alerting
- [ ] **Backup**: Configure backup strategy
- [ ] **Security**: Review security settings and network policies

### Production Configuration Example

```yaml
# production-values.yaml
teable:
  publicOrigin: "https://teable.company.com"
  jwtSecret: "your-secure-64-character-jwt-secret-change-this"
  sessionSecret: "your-secure-64-character-session-secret-change-this"

database:
  url: "postgresql://teable_user:secure_password@managed-postgres.company.com:5432/teable"

cache:
  redisUri: "redis://managed-redis.company.com:6379/0"

storage:
  minio:
    endpoint: "s3.company.com"
    accessKey: "your-production-access-key"
    secretKey: "your-production-secret-key"
    useSSL: "true"
  prefix: "https://s3.company.com"

resources:
  limits:
    cpu: 4000m
    memory: 8192Mi
  requests:
    cpu: 1000m
    memory: 2048Mi

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: teable.company.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: teable-tls
      hosts:
        - teable.company.com
```

### Production Installation

```bash
# Generate production manifests
./generate-k8s.sh \
  --namespace teable-prod \
  --release teable-prod \
  --public-origin https://teable.company.com \
  --database-url "postgresql://user:pass@prod-db:5432/teable"

# Deploy
cd k8s-manifests
./install.sh
```

---

## 🧰 Useful Commands and Scripts

### Makefile Commands

```bash
make install          # Install with defaults
make status           # Check deployment status  
make logs             # View application logs
make port-forward     # Access via localhost:8080
make test             # Test deployment health
make clean            # Clean up generated files
```

### Direct kubectl Commands

```bash
# Get all resources
kubectl get all -l app.kubernetes.io/name=teable -n teable

# Scale deployment
kubectl scale deployment teable --replicas=3 -n teable

# Update image
kubectl set image deployment/teable teable=ghcr.io/teableio/teable:v1.2.3 -n teable

# Delete deployment
kubectl delete deployment teable -n teable
```

---

## 🆘 Getting Help

### Documentation
- [Teable Documentation](https://docs.teable.io)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)

### Troubleshooting Resources
- Check application logs: `kubectl logs -l app.kubernetes.io/name=teable -n teable`
- Run status check: `./check-status.sh`
- Review generated manifests in `k8s-manifests/`
- Test external services: `docker-compose ps`

### Community Support
- [Teable GitHub Issues](https://github.com/teableio/teable/issues)
- [Teable Community Discussions](https://github.com/teableio/teable/discussions)

---

## 📝 Summary

This installation guide provides multiple paths to deploy Teable on Kubernetes:

1. **Quick Start**: Use `./generate-k8s.sh` + `docker-compose` for immediate deployment
2. **Development**: Use static manifests with Docker Compose dependencies
3. **Production**: Use Helm charts with external managed services

Choose the method that best fits your needs and environment. The static manifest approach is recommended for most users due to its simplicity and reliability.

**Next Steps**: After installation, configure your Teable instance, set up user accounts, and explore the collaborative database features!