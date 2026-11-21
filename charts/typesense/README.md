# typesense

Helm chart for [Typesense](https://typesense.org/), a fast, typo-tolerant search engine.

## Install

```bash
helm install my-release oci://ghcr.io/prefeitura-rio/charts/typesense
```

See `values.yaml` for configuration options.

## API key

By default the chart passes `apiKey` in plain text, both in the
`TYPESENSE_API_KEY` env var and in the `--api-key` argument, so anyone who can
read the StatefulSet or its pods sees the key.

To keep the key out of the spec, point `apiKeySecret` at an existing `Secret`
(the chart does not create it):

```yaml
apiKeySecret:
  name: typesense-api-key # Secret in the release namespace
  key: api-key            # key inside the Secret (default: api-key)
```

With `apiKeySecret.name` set, `TYPESENSE_API_KEY` is read with
`valueFrom.secretKeyRef`, the argument becomes `--api-key $(TYPESENSE_API_KEY)`
(expanded by Kubernetes) and `apiKey` is ignored. Rendering fails if
`apiKeySecret.name` is set and `apiKeySecret.key` is empty. Leaving
`apiKeySecret.name` empty (the default) keeps the plain-text `apiKey` behavior.
The Secret must exist before the pods start: if it or the key is missing, the
pods stay in `CreateContainerConfigError`.

| Value | Default | Description |
| --- | --- | --- |
| `apiKey` | `"xyz"` | API key in plain text; ignored when `apiKeySecret.name` is set |
| `apiKeySecret.name` | `""` | Name of an existing Secret holding the API key |
| `apiKeySecret.key` | `api-key` | Key inside that Secret |
