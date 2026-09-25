# Kodus

Helm chart for the self-hosted Kodus AI pull-request review platform.

This chart is based on the Kodus installer snapshot documented in
`/home/vitor/Projects/kodus_helm_guide.md`:

- Kodus release: `2.1.31`
- Chart version: `0.2.3`
- Source commit: `674b02f17792052cbef20fe82285d9504056b69a`

The chart deploys the Kodus web, API, webhook, and worker services. It can also
run bundled PostgreSQL, MongoDB, and RabbitMQ for a short-lived pilot. Use
external services or Kubernetes operators for production.

## Dependency

`kodus-common` is a local Helm library dependency. Build it before rendering
the chart:

```bash
helm dependency build charts/kodus/kodus
```

The library chart is not installed independently.

## Pilot

Start with the non-secret example overlay:

```bash
helm upgrade --install kodus charts/kodus/kodus \
  --namespace kodus-pilot \
  --create-namespace \
  --values charts/kodus/kodus/values-pilot.example.yaml
```

Before connecting GitHub, replace the placeholder webhook DNS name, create the
TLS Secret referenced by the overlay, and configure private access to the web
UI and API. Configure the approved secret source for the LLM credential. Never
commit API keys, GitHub App credentials, passwords, or signing keys to a values
file.

See [`docs/kodus-pilot-pr-review.md`](../docs/kodus-pilot-pr-review.md) for
the staged rollout and acceptance checks.

## Integration boundary

Kodus is an asynchronous pull-request service. GitHub sends a webhook, Kodus
queues the review, a worker calls the configured provider, and Kodus publishes
the result back to GitHub. It is not a synchronous step in the existing
`quality-gate` action.

The Bifrost endpoint and DeepSeek model are documented in the pilot runbook,
but the virtual key remains an external secret-management concern.

When `global.existingSecret` or ExternalSecrets are used, bump
`global.secretVersion` whenever the referenced Secret rotates so the workloads
restart and receive the new environment variables.
