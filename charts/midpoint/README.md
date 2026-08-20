# Midpoint

Helm chart for [MidPoint](https://evolveum.com/midpoint/), Evolveum's open-source Identity Governance and Administration (IGA) platform.

Manages only MidPoint's own workload (Deployment, PVC, Secrets, ServiceAccount, Service, PDB) plus repository/connector/schema-extension bootstrap and REST-based resource import. Network policy, service mesh authorization, and ingress are expected to be managed separately.

## Install

```bash
helm install my-release oci://ghcr.io/prefeitura-rio/charts/midpoint \
  --set database.host=postgres.example.svc.cluster.local \
  --set database.password=changeme \
  --set admin.password=changeme
```

See `values.yaml` for configuration options.
