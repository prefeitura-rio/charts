# agent-sandbox

Vendored copy of the [Agent Sandbox](https://github.com/kubernetes-sigs/agent-sandbox) Helm chart (SIG Apps), pinned to upstream `v0.5.6`. Manages `Sandbox` CRDs and the controller for isolated, stateful, singleton pod workloads (e.g. AI agent runtimes).

## Install

```bash
helm install agent-sandbox oci://ghcr.io/prefeitura-rio/charts/agent-sandbox \
  --namespace agent-sandbox-system \
  --create-namespace \
  --set image.tag=v0.5.6
```

`image.tag` is required. See `values.yaml` for configuration options.

> **Note**: Helm does not manage CRDs on upgrade/uninstall — apply/delete `crds/` manually when needed.
