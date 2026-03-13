# typesense

Helm chart for deploying [Typesense](https://typesense.org/) - a fast, typo-tolerant search engine optimized for instant search experiences.

## Features

- Lightning-fast search
- Typo tolerance
- Faceting and filtering
- Geo-search support
- Clustering support
- High availability
- Persistent storage
- PodDisruptionBudget

## Quick Start

```bash
# Single node deployment
helm install typesense prefeitura-rio/typesense \
  --set replicas=1 \
  --set apiKey=your-secret-api-key
```

## Configuration

### Single Node Setup

```yaml
replicas: 1
apiKey: "your-secret-api-key"

persistence:
  enabled: true
  size: 25Gi
```

### Multi-Node Cluster (High Availability)

```yaml
replicas: 3
apiKey: "your-secret-api-key"

persistence:
  enabled: true
  size: 50Gi

pdb:
  enabled: true
  minAvailable: 2
```

### With Custom Storage

```yaml
persistence:
  enabled: true
  size: 100Gi
  storageClass: fast-ssd
```

### With Resource Limits

```yaml
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
podSecurityContext:
  fsGroup: 1001

securityContext:
  runAsUser: 1001
  runAsNonRoot: true
```

### With Load Balancer

```yaml
service:
  type: LoadBalancer
  port: 80
```

### With Custom Environment Variables

```yaml
extraEnv:
  - name: TYPESENSE_ENABLE_CORS
    value: "true"
  - name: TYPESENSE_LOG_LEVEL
    value: "info"
```

## Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicas` | Number of Typesense nodes | `3` |
| `apiKey` | API key for authentication | `xyz` |
| `image.tag` | Typesense version | `30.1` |
| `applicationPort` | HTTP API port | `8108` |
| `peeringPort` | Cluster peering port | `8107` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | Storage size | `25Gi` |
| `persistence.storageClass` | Storage class | `""` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `pdb.enabled` | Enable PodDisruptionBudget | `true` |
| `pdb.minAvailable` | Minimum available pods | `1` |

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

The chart includes three types of probes:

- **Startup**: Initial delay 10s, failure threshold 30 (allows 5 minutes for startup)
- **Liveness**: Initial delay 120s, checks every 10s
- **Readiness**: Initial delay 30s, checks every 5s

All probes check the `/health` endpoint.

## Clustering

When `replicas > 1`, Typesense automatically configures a cluster:

- Each pod gets a stable network identity via StatefulSet
- Cluster nodes discover each other via headless service
- Data is replicated across all nodes
- Use PodDisruptionBudget to ensure cluster availability during updates

## Storage

Data is stored in persistent volumes at `/data`. Each pod gets its own PVC.

## Services

Two services are created:

- **Regular service** (`typesense`): For external access
- **Cluster service** (`typesense-cluster`): Headless service for pod-to-pod communication

## Security

**IMPORTANT**: Change the default `apiKey` in production!

```yaml
apiKey: "your-very-secret-api-key-here"
```

Consider storing it in a Kubernetes Secret and referencing it via `extraEnv`.

## Documentation

- [Typesense Documentation](https://typesense.org/docs/)
- [Typesense GitHub](https://github.com/typesense/typesense)
- [High Availability Guide](https://typesense.org/docs/guide/high-availability.html)
