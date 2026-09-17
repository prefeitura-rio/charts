# cloudsql-proxy

[Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy) for secure connections to Google Cloud SQL instances.

## Install

```bash
helm install my-release oci://ghcr.io/prefeitura-rio/charts/cloudsql-proxy
```

See `values.yaml` for configuration options.

## Multiple instances

The chart renders one proxy and backend Service per item:

```yaml
instances:
  - project: rj-iplanrio-dia
    instance: postgres
    region: us-central1
    port: 5432
    listenPort: 10000

  - project: rj-sme-danfe-ai
    instance: mysql
    region: us-central1
    port: 3306
    listenPort: 10001
```

Set `routing.enabled: true` to also render an Istio TCP Gateway, a TCP VirtualService, and one Tailscale LoadBalancer Service for the frontend ports.
