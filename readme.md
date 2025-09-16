## Prerequisites

###

Teable Images

- Application image: `ghcr.io/teableio/teable:latest`

###

Runtime Environment

- Running Kubernetes cluster

###

Required External Services

###

Database Service

- PostgreSQL database: postgres:15.4 (version > 12)
    - PG image: `postgres:15.4`

###

Cache Service

- Redis cache service: redis:7.2.4 (version > 5)
    - Redis image: `redis:7.2.4`

###

Object Storage Service

- MinIO object storage service: `minio:latest`

###

Required Tools

- kubectl command-line tool

## Dependency Component Configuration

###

File Storage (MinIO)

File storage service must be accessible from the public internet (directly accessible by end users)

Two buckets need to be created in advance for file storage.

1. Public readable bucket, configured with public read permissions

    BACKEND_STORAGE_PUBLIC_BUCKET=teable-pub

2. Private bucket, no special permission configuration needed

    BACKEND_STORAGE_PRIVATE_BUCKET=teable-pvt


Teable MinIO Environment Variables Overview

```
# Fixed value
BACKEND_STORAGE_PROVIDER=minio
# Public bucket
BACKEND_STORAGE_PUBLIC_BUCKET=teable-pub
# Private bucket
BACKEND_STORAGE_PRIVATE_BUCKET=teable-pvt
# Public endpoint, important! Must be accessible by end users
BACKEND_STORAGE_MINIO_ENDPOINT=minio.example.com
# Same as above but with protocol
STORAGE_PREFIX=https://minio.example.com
# Internal network endpoint
BACKEND_STORAGE_MINIO_INTERNAL_ENDPOINT=internal.network
# Public port, typically 443 or 9000
BACKEND_STORAGE_MINIO_PORT=443
# Internal network port, typically 80 or 9000
BACKEND_STORAGE_MINIO_INTERNAL_PORT=80
# Enable HTTPS, note: if Teable uses HTTPS, MinIO must also use HTTPS to avoid CORS issues
BACKEND_STORAGE_MINIO_USE_SSL="true"
# Admin account
BACKEND_STORAGE_MINIO_ACCESS_KEY=root
# Admin password
BACKEND_STORAGE_MINIO_SECRET_KEY=rootPassword
```

###

Database

Create a database account with administrative privileges, a database, and set a password. Environment variables example:

- Database name: teable
- Password: your-password
- Username: postgres
- Port: 5432

    PRISMA_DATABASE_URL="postgresql://postgres:your-password@your-postgres-host:5432/teable"


###

Redis Cache

Teable only needs the internal network address for Redis cache configuration. (Note: Redis manages both cache and queues, it’s essential. Data should be backed up regularly) Environment variables example:

```
BACKEND_CACHE_REDIS_URI="redis://username:password@your-redis-host:6379/0"
```

## Create Configuration Files

teable-config.yaml (Non-sensitive configuration)

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: teable-config
data:
  # Application base configuration, public access domain
  PUBLIC_ORIGIN: "https://your-domain.com"

  # Storage configuration
  BACKEND_STORAGE_PROVIDER: "minio"
  # Public endpoint, important! Must be accessible by end users
  BACKEND_STORAGE_MINIO_ENDPOINT: "minio.example.com"
  # Same as above but with protocol
  STORAGE_PREFIX: "https://minio.example.com"
  # Internal endpoint
  BACKEND_STORAGE_MINIO_INTERNAL_ENDPOINT: "minio.namespace.svc"
  # Public port, typically 443 or 9000
  BACKEND_STORAGE_MINIO_PORT: "443"
  # Internal port, typically 80 or 9000
  BACKEND_STORAGE_MINIO_INTERNAL_PORT: "80"
  # Enable HTTPS, note: if Teable uses HTTPS, MinIO must also use HTTPS to avoid CORS issues
  BACKEND_STORAGE_MINIO_USE_SSL: "true"

  # Cache configuration, fixed value
  BACKEND_CACHE_PROVIDER: "redis"

  # Other configurations, fixed values
  NEXT_ENV_IMAGES_ALL_REMOTE: "true"
  PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING: "1"
  # Keep this when using self-signed certificates
  NODE_TLS_REJECT_UNAUTHORIZED: '0'
```

secrets.yaml (Sensitive information)

```
apiVersion: v1
kind: Secret
metadata:
  name: teable-secrets
type: Opaque
stringData:
  # Database sensitive information
  PRISMA_DATABASE_URL: "postgresql://postgres:your-password@your-postgres-host:5432/teable"

  # Application secrets
  BACKEND_JWT_SECRET: "your-jwt-secret"
  BACKEND_SESSION_SECRET: "your-session-secret"

  # MinIO authentication
  BACKEND_STORAGE_PUBLIC_BUCKET: "teable-pub"
  BACKEND_STORAGE_PRIVATE_BUCKET: "teable-pvt"
  BACKEND_STORAGE_MINIO_ACCESS_KEY: "your-minio-access-key"
  BACKEND_STORAGE_MINIO_SECRET_KEY: "your-minio-secret-key"

  # Redis authentication
  BACKEND_CACHE_REDIS_URI: "redis://username:password@your-redis-host:6379/0"
```

deployment.yaml

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: teable
spec:
  replicas: 1 # Configure as needed
  selector:
    matchLabels:
      app: teable
  template:
    metadata:
      labels:
        app: teable
    spec:
      # Add initContainers for database migration
      initContainers:
        - name: db-migrate
          image: ghcr.io/teableio/teable:latest
          args:
            - migrate-only
          envFrom:
            - configMapRef:
                name: teable-config
            - secretRef:
                name: teable-secrets
          resources:
            requests:
              cpu: 100m
              memory: 102Mi
            limits:
              cpu: 1000m
              memory: 1024Mi
      containers:
        - name: teable
          image: ghcr.io/teableio/teable:latest
          args:
            - skip-migrate
          ports:
            - containerPort: 3000
          envFrom:
            - configMapRef:
                name: teable-config
            - secretRef:
                name: teable-secrets
          resources:
            requests:
              cpu: 200m
              memory: 400Mi
            limits:
              cpu: 2000m
              memory: 4096Mi
          startupProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 30
            successThreshold: 1
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 30
            timeoutSeconds: 5
            failureThreshold: 3
            successThreshold: 1
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
            successThreshold: 1
```

service.yaml

```
apiVersion: v1
kind: Service
metadata:
  name: teable
spec:
  ports:
    - port: 3000
      targetPort: 3000
  selector:
    app: teable
```

ingress.yaml (Optional)

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: teable
  # Example using nginx, if using other ingress class, please replace
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "128k"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
spec:
  rules:
    - host: your-domain.com  # Application base configuration, public access domain
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: teable
                port:
                  number: 3000
  tls:
    - hosts:
        - your-domain.com  # Application base configuration, public access domain
      secretName: your-tls-secret
```

## Deployment Steps

1. Create configuration and secrets:
```
    kubectl apply -f config.yaml
    kubectl apply -f secrets.yaml
```
2. Deploy application:
```
    kubectl apply -f deployment.yaml
    kubectl apply -f service.yaml
    kubectl apply -f ingress.yaml
```
3. Verify deployment:
```
    # Check Pod status

    kubectl get pods -l app=teable

    # View application logs

    kubectl logs -l app=teable
```

###

Configuration Notes

1. Sensitive Information Management
- All password, secret-related information should be managed through Secrets
1. Database Configuration
- Ensure that the teable database exists in the database
- The database user needs to have appropriate permissions
- It’s recommended to use a connection pool to manage database connections
1. MinIO Configuration
- Ensure that the storage bucket exists and the permissions are correct, one public bucket, one private bucket
- The public bucket needs to be completely publicly readable
- The internal and external access address configuration is correct
1. Redis Configuration
- It’s recommended to enable Redis persistence
- Configure appropriate memory limits
- Consider using Redis cluster to improve availability
1. Security Recommendations
- Use strong passwords and secrets
- Enable TLS/SSL encryption
- Regularly update certificates
- Limit network access scope
1. Resource Configuration
- Adjust resource limits based on actual load
- Monitor resource usage
- Configure appropriate health check parameters

###

Troubleshooting

1. Check Pod status:
```
    kubectl describe pod -l app=teable
```
2. View application logs:
```
    kubectl logs -l app=teable
```
3. Verify configuration:
```
    kubectl describe configmap teable-config
    kubectl describe secret teable-secrets
```
4. Check network connection:
```
    kubectl exec -it  -- curl -v localhost:3000/health
```
