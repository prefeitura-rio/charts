# letta

Helm chart for deploying [Letta](https://www.letta.com/) - an open-source framework for building stateful LLM applications with long-term memory.

## Features

- Stateful LLM applications
- Long-term memory management
- Built-in PostgreSQL database
- Persistent storage support
- Health probes
- Security contexts
- ArgoCD integration

## Quick Start

```bash
helm install letta prefeitura-rio/letta
```

## Configuration

### Basic Setup

```yaml
deployment:
  image: letta/letta:latest
  replicaCount: 1

persistence:
  enabled: true
  size: 10Gi
```

### With Custom Environment Variables

```yaml
deployment:
  env:
    LETTA_LOG_LEVEL: "debug"
    LETTA_SERVER_PORT: "8283"
```

### With Secrets

```yaml
deployment:
  envFromSecret: letta-secrets
```

### With Ingress

```yaml
ingress:
  enabled: true
  host: letta.example.com
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  tls:
    - hosts:
        - letta.example.com
      secretName: letta-tls
```

### With Resource Limits

```yaml
deployment:
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 4Gi
```

### With Security Context

```yaml
deployment:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    capabilities:
      drop:
        - ALL
```

### With ArgoCD

```yaml
argocd:
  enabled: true
```

## Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `deployment.image` | Container image | `letta/letta:latest` |
| `deployment.replicaCount` | Number of replicas | `1` |
| `deployment.env` | Environment variables (dict) | `{}` |
| `deployment.envFromSecret` | Secret name for env vars | `""` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | Storage size | `10Gi` |
| `persistence.storageClassName` | Storage class | `""` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.host` | Ingress hostname | `letta.example.com` |

## Development

```bash
# Lint the chart
just lint

# Run tests
just test

# Package the chart
just package
```

## Health Checks

The chart includes liveness and readiness probes that check `/health`:

- **Liveness**: Initial delay 30s, period 10s
- **Readiness**: Initial delay 10s, period 5s

## Storage

The chart creates a PersistentVolumeClaim for PostgreSQL data storage. The data is stored at `/var/lib/postgresql/data`.

## Documentation

- [Letta Documentation](https://docs.letta.com/)
- [Docker Quickstart](https://docs.letta.com/quickstart/docker)
