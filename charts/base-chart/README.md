# base-chart

Production-ready Helm chart for deploying applications on Kubernetes.

## Features

- **Service Mesh**: Istio integration (VirtualService, DestinationRule, AuthorizationPolicy)
- **Autoscaling**: HPA and KEDA ScaledObject
- **Secrets**: Infisical integration
- **High Availability**: PodDisruptionBudget, pod anti-affinity
- **CI/CD**: Argo CD sync waves, ArgoCD Image Updater
- **Dependencies**: Optional Valkey (Redis) and RabbitMQ
- **Jobs**: CronJob and init containers support

## Quick Start

```bash
helm install my-app prefeitura-rio/base-chart \
  --set image.repository=myorg/myapp \
  --set image.tag=v1.0.0
```

## Common Configurations

### Basic Deployment

```yaml
image:
  repository: myorg/myapp
  tag: v1.0.0

service:
  enabled: true
  port: 8080

ingress:
  enabled: true
  host: myapp.example.com
```

### With Autoscaling

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### With Istio

```yaml
istio:
  virtualService:
    enabled: true
    host: myapp.example.com
  destinationRule:
    enabled: true
```

### With Redis (Valkey)

```yaml
valkey:
  enabled: true
  architecture: standalone
```

### With Secrets (Infisical)

```yaml
infisicalSecret:
  enabled: true
  secretsPath: /app/production
  managedSecretReference: my-infisical-token
```

## Configuration

See [values.yaml](values.yaml) for all available options. Key sections:

- `image`: Container image configuration
- `service`: Kubernetes Service settings
- `ingress`: Ingress configuration
- `autoscaling`: HPA settings
- `istio`: Service mesh configuration
- `valkey`: Redis configuration
- `rabbitmq`: RabbitMQ configuration
- `cronjobs`: Scheduled jobs
- `initContainers`: Init containers for migrations

## Development

```bash
# Lint the chart
just lint

# Run tests
just test

# Package the chart
just package
```

## Testing

```bash
# Run unit tests
helm unittest .

# Test with all features enabled
just test
```
