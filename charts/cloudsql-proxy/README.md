# cloudsql-proxy

[Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy) for secure connections to Google Cloud SQL instances.

## Install

```bash
helm install my-release oci://ghcr.io/prefeitura-rio/charts/cloudsql-proxy
```

See `values.yaml` for configuration options.

## Multiple instances

The chart renders one proxy Deployment and backend Service per item:

```yaml
instances:
  - project: rj-iplanrio-dia
    instance: postgres
    serviceName: postgres
    region: us-central1
    port: 5432
    listenPort: 5432

  - project: rj-sme-danfe-ai
    instance: mysql
    serviceName: danfe
    region: us-central1
    port: 3306
    listenPort: 10000
```

`serviceName` is optional. Without it, the chart uses the sanitized project and instance name.

## Exposure strategies

Use `routing.strategy` to select how clients reach the proxy:

### Multiservice

```yaml
routing:
  strategy: multiservice
```

This is the default strategy. It exposes one ClusterIP Service per instance. Clients in the same namespace can use short names such as `postgres:5432` and `danfe:10000`. It does not render Istio or Tailscale resources.

### Istio gateway

```yaml
routing:
  strategy: istio-gateway
  gateway:
    name: cloudsql-gateway
    namespace: istio-system
    selector:
      app: istio-ingressgateway
      istio: ingressgateway
  tailscale:
    hostname: cloudsql-proxy
    tags: tag:k8s-iplan
```

This keeps the backend Services and also renders an Istio TCP Gateway, a TCP VirtualService, and one Tailscale LoadBalancer Service for the configured frontend ports.

For backwards compatibility, `routing.enabled: true` selects `istio-gateway` when `routing.strategy` is empty. An explicit strategy takes precedence.
