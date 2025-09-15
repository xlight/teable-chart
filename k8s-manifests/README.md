# Teable Kubernetes Manifests

This directory contains static Kubernetes manifests for deploying Teable.

## Generated Configuration

- **Namespace**: teable
- **Release Name**: teable
- **Public Origin**: http://localhost:8080
- **Database**: External PostgreSQL
- **Cache**: External Redis
- **Storage**: External MinIO

## Prerequisites

1. **External Services**: Ensure PostgreSQL, Redis, and MinIO are running and accessible
2. **kubectl**: Kubernetes command-line tool
3. **Cluster Access**: kubectl configured to access your cluster

## Quick Start

### 1. Start Dependencies (if using Docker Compose)

```bash
# From the parent directory
docker-compose up -d
```

### 2. Install Teable

```bash
# Install with generated script
./install.sh

# Or manually apply manifests
kubectl apply -f .
```

### 3. Access Application

```bash
# Port forward to access locally
kubectl port-forward svc/teable 8080:3000 -n teable

# Visit http://localhost:8080
```

## Files Description

- `namespace.yaml`: Kubernetes namespace
- `configmap.yaml`: Non-sensitive configuration
- `secret.yaml`: Sensitive configuration (passwords, keys)
- `serviceaccount.yaml`: Service account for pods
- `deployment.yaml`: Main application deployment
- `service.yaml`: Kubernetes service
- `ingress.yaml`: Ingress configuration (commented out)
- `install.sh`: Installation script
- `uninstall.sh`: Uninstallation script

## Customization

To modify the configuration:

1. Edit the YAML files directly
2. Or regenerate with different parameters:
   ```bash
   # From parent directory
   ./generate-k8s.sh --public-origin https://your-domain.com --namespace production
   ```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n teable
kubectl describe pods -l app.kubernetes.io/name=teable -n teable
```

### View Logs
```bash
# Application logs
kubectl logs -l app.kubernetes.io/name=teable -n teable

# Migration logs
kubectl logs -l app.kubernetes.io/name=teable -c db-migrate -n teable
```

### Test Connectivity
```bash
# Test health endpoint
kubectl exec -it deployment/teable -n teable -- curl http://localhost:3000/health
```

## Production Considerations

1. **Update Secrets**: Change JWT and session secrets in `secret.yaml`
2. **External Services**: Use managed PostgreSQL, Redis, and MinIO
3. **TLS/SSL**: Configure proper certificates
4. **Resources**: Adjust CPU and memory limits based on load
5. **Monitoring**: Set up monitoring and alerting
6. **Backup**: Configure backup strategy for data

