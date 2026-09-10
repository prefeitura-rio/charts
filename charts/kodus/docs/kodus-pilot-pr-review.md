# Kodus Pilot PR Review Runbook

This runbook stages Kodus as an advisory AI review service alongside the
existing deterministic quality gate. It deliberately does not make Kodus a
synchronous GitHub Actions step or a merge blocker.

## Prerequisites

- Kubernetes 1.28+ and Helm 3.8+.
- An ingress controller and a certificate for the web, API, and webhook hosts.
- DNS records for the three public hosts in the pilot values file.
- An approved secret source for the LLM credential and GitHub App credentials.
- A GitHub App with repository read, pull-request review/comment, and webhook
  permissions approved by the platform owner.

The initial pilot uses bundled PostgreSQL, MongoDB, and RabbitMQ. They are
intended for evaluation only and require persistent volumes. Production must
use external services or supported operators.

## Stage 1: Review the chart

Run these checks before deploying:

```bash
helm dependency build charts/kodus/kodus
helm lint charts/kodus/kodus -f charts/kodus/kodus/values-pilot.example.yaml
helm template kodus charts/kodus/kodus \
  --namespace kodus-pilot \
  -f charts/kodus/kodus/values-pilot.example.yaml > /tmp/kodus-pilot.yaml
helm unittest charts/kodus/kodus
```

Inspect the rendered output for public hosts, secret references, image tags,
resource requests, and the absence of inline credentials.

## Stage 2: Deploy an isolated pilot

Replace the example hosts and TLS Secret name in a local, untracked values
file. Install into a namespace dedicated to the pilot:

```bash
helm upgrade --install kodus charts/kodus/kodus \
  --namespace kodus-pilot \
  --create-namespace \
  --values charts/kodus/kodus/values-pilot.example.yaml \
  --values /path/to/kodus-pilot-private.yaml
```

Check migrations, application readiness, storage, and webhook reachability:

```bash
kubectl get pods,job,pvc,ingress -n kodus-pilot
kubectl logs -n kodus-pilot -l app.kubernetes.io/name=api --tail=100
helm test kodus -n kodus-pilot
```

The webhook endpoint must be reachable at:

```text
https://<webhooks-host>/github/webhook
```

Do not place the webhook service behind an `/api` or `/webhooks` path prefix.

## Stage 3: Configure providers

Create or install the GitHub App through the approved process. Configure one
pilot repository only, and verify that GitHub can deliver events to the public
webhook host.

Configure Kodus BYOK with:

```text
Endpoint: https://bifrost.iplan.dados.rio/openai/v1
Model:    Huawei/deepseek-v4-flash
```

The Bifrost virtual key must come from the approved secret manager. Its secret
name and path are intentionally not encoded in this repository until the
platform decision is complete.

## Stage 4: Run the review experiment

Use two small pull requests in the pilot repository:

1. A compliant change that follows the repository styleguide and quality-gate
   rules.
2. A deliberately non-compliant change containing a documented, safe review
   target.

For each pull request record whether the webhook arrived, review latency,
provider errors, useful findings, false positives, and duplicate comments.
Confirm that the existing quality gate remains independent and continues to
report its deterministic result.

## Stage 5: Decide the policy

Start with advisory comments only. After the pilot, the quality owner and
repository owners decide whether Kodus remains advisory or becomes
merge-blocking. Define an exception owner and an escalation path before
changing branch protection rules.

## Upgrade and rollback

Pin the chart and image versions. Before an upgrade, back up the bundled
datastores or verify the external/operator backup policy:

```bash
helm history kodus -n kodus-pilot
helm upgrade kodus charts/kodus/kodus -n kodus-pilot \
  -f charts/kodus/kodus/values-pilot.example.yaml \
  -f /path/to/kodus-pilot-private.yaml
helm rollback kodus <revision> -n kodus-pilot
```

Database migrations are not automatically reverted by a Helm rollback. Treat
major Kodus upgrades as a migration change and follow the release notes.

## Exit criteria

- All application pods and the migration Job are healthy.
- `helm test` passes.
- GitHub delivers a webhook and Kodus creates a review.
- The compliant PR receives no unsupported blocking finding.
- The non-compliant PR receives actionable feedback.
- Logs, latency, false positives, and provider failures are recorded.
- Owners approve the next step for secrets, production datastores, and merge
  policy.
