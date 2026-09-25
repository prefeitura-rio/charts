# Kodus Deployment Contract

This document defines the remaining work required to deploy and operate Kodus
as the AI-assisted pull-request review service for the quality gate.

Kodus is an asynchronous pull-request service. It is not a synchronous step in
the existing GitHub Actions quality-gate workflow.

## Current State

The chart is deployment-ready for a bundled, non-integrated pilot, but it is
not yet wired for a real GitHub organization or production secret management.

Known gaps:

- GitHub App and OAuth credentials require an approved Secret source and actual
  provider credentials; the chart now supports their optional Secret injection.
- The current `ExternalSecret` only exposes fixed `kodus/<KEY>` paths.
- Infisical integration is not implemented.
- Bifrost URL and model variables are absent from the chart defaults.
- The pilot uses generated application secrets and bundled datastores.
- DNS, TLS, GitHub App, provider key, and merge policy are undefined.
- The current kube context is `gke_rj-civitas-dev_us-central1_civitas-cluster`.
  Treat it as a possible pilot target, not production, until explicitly confirmed.

## Runtime Flow

```text
GitHub PR
  -> https://<webhooks-host>/github/webhook
  -> Kodus webhooks
  -> Kodus API
  -> RabbitMQ
  -> Kodus worker
  -> Bifrost OpenAI-compatible API
  -> openai.gpt-5.6-luna
  -> GitHub review comments
```

## Execution Plan

### 1. Confirm Deployment Decisions

Record the following before creating private deployment values:

- Target cluster and Kubernetes context.
- Namespace, recommended initial value: `kodus-pilot`.
- Kubernetes Ingress versus OpenShift Route.
- Ingress class and cert-manager issuer.
- Actual public DNS names.
- Infisical project, environment, path, and Kubernetes authentication Secret.
- Bundled versus external/operator-managed datastores.
- GitHub organization and pilot repository.
- GitHub App ownership and OAuth App ownership.
- Whether telemetry is allowed.
- Initial policy: advisory only, with no merge blocking.

### 2. Reserve DNS and TLS

The iplanrio deployment keeps the web UI and API private through Tailscale and
publishes only the webhook endpoint:

```text
Web:      https://kodus.<tailscale-domain>
API:      https://kodus-api.<tailscale-domain>
Webhooks: https://kodus-webhooks.iplan.dados.rio
```

Required application URLs:

```text
NEXTAUTH_URL:
  https://<kodus-web-host>

GitHub App callback:
  https://<kodus-web-host>/api/auth/callback/github

GitHub App setup:
  https://<kodus-web-host>/setup/github

GitHub webhook:
  https://<kodus-webhooks-host>/github/webhook

MCP OAuth callback, if MCP is enabled:
  https://<kodus-web-host>/setup/mcp/oauth
```

Requirements:

- The webhook host must be publicly reachable over HTTPS.
- Do not expose webhooks behind `/api` or `/webhooks` path prefixes.
- Create the TLS Secret or configure cert-manager.
- Validate the certificate with `curl` using certificate verification enabled.
- Configure the chart to derive webhook URLs from the real webhook hostname.

### 3. Complete the Chart Secret Contract

Extend `charts/kodus/kodus-common/templates/_env.tpl`,
`charts/kodus/kodus/values.yaml`, `templates/secrets.yaml`, and
`templates/externalsecret.yaml`.

Required application secrets:

```text
API_JWT_SECRET
API_JWT_REFRESH_SECRET
WEB_NEXTAUTH_SECRET
NEXTAUTH_SECRET
API_CRYPTO_KEY
CODE_MANAGEMENT_SECRET
```

Format requirements:

- `API_CRYPTO_KEY`: 64 hexadecimal characters.
- `CODE_MANAGEMENT_SECRET`: 64 hexadecimal characters.
- `WEB_NEXTAUTH_SECRET` and `NEXTAUTH_SECRET`: identical values.

GitHub App integration:

```text
API_GITHUB_CLIENT_SECRET
API_GITHUB_PRIVATE_KEY
```

GitHub OAuth login:

```text
WEB_OAUTH_GITHUB_CLIENT_SECRET
```

The chart injects these sensitive GitHub values through `secretKeyRef` when
`global.existingSecret` is configured. The non-sensitive App ID, installation
URL, and OAuth client ID remain ConfigMap configuration.

Non-secret GitHub configuration:

```text
API_GITHUB_APP_ID
WEB_GITHUB_INSTALL_URL
WEB_OAUTH_GITHUB_CLIENT_ID
```

Bifrost:

```text
API_OPEN_AI_API_KEY
```

Optional production integrations:

```text
API_EXA_KEY
RESEND_API_KEY
API_SMTP_PASS
LANGFUSE_SECRET_KEY
API_E2B_KEY
API_MCP_MANAGER_JWT_SECRET
API_MCP_MANAGER_ENCRYPTION_SECRET
```

The exact GitHub variable names must be validated against Kodus release
`2.1.31` before implementation.

### 4. Implement Infisical Integration

Add an Infisical-backed Secret option following the existing `base-chart`
convention.

Recommended target:

```text
Kubernetes Secret: kodus-secrets
Namespace:          <release namespace>
Infisical path:     /kodus
```

Required behavior:

- `global.existingSecret` points to `kodus-secrets`.
- `global.externalSecrets.enabled` remains `false`.
- `global.autoGenerateSecrets` is `false`.
- Secrets are populated by Infisical, never committed to Helm values.
- GitHub and Bifrost keys are included in the generated Secret.
- Datastore credentials remain in separate Secrets unless the organization
  explicitly standardizes on one Secret.
- Secret rotation is documented and triggers a controlled rollout restart or
  uses an approved reloader.

The generic `ExternalSecret` should either be extended with configurable remote
paths and all required keys, or documented as a separate alternative. It must
never be enabled together with `global.existingSecret`.

### 5. Choose and Prepare Datastores

For the pilot:

- Bundled PostgreSQL, MongoDB, and RabbitMQ are acceptable.
- Confirm StorageClass and PVC capacity.
- Confirm resource quota and node capacity.

For production, prefer external or operator mode.

External PostgreSQL requires:

- Dedicated database and user.
- pgvector enabled.
- Secret containing the configured password key.
- TLS decision; set `API_DATABASE_DISABLE_SSL=false` when required.

External MongoDB requires:

- User created in the `admin` authentication database.
- Access to the Kodus database.
- Password Secret.

External RabbitMQ requires:

- `rabbitmq_delayed_message_exchange` enabled.
- `kodus-ai` vhost.
- User permissions on that vhost.
- Secret containing a complete URI, such as:

```text
amqps://user:password@host:5671/kodus-ai
```

### 6. Add Bifrost Configuration

Add these non-secret values to the chart contract:

```text
API_OPENAI_FORCE_BASE_URL=https://bifrost.iplan.dados.rio/openai/v1
API_LLM_PROVIDER_MODEL=openai.gpt-5.6-luna
```

Inject only the virtual key through the Secret:

```text
API_OPEN_AI_API_KEY
```

Validate:

- DNS resolution from the worker Pod.
- TLS trust.
- NetworkPolicy egress.
- Authentication.
- Model availability.
- Rate and concurrency limits.
- A fallback provider or model, if supported and approved.

The alternative is configuring Bifrost through Kodus's BYOK UI. For the initial
controlled pilot, fixed environment configuration is more reproducible.

### 7. Create Private Deployment Values

Keep the committed pilot overlay non-secret. Create an untracked or externally
managed private overlay containing:

- Actual Tailscale and webhook DNS names.
- TLS Secret name.
- `global.existingSecret`.
- SOPS-backed Secret configuration.
- Datastore mode and Secret names.
- Bifrost model configuration.
- Any GitHub integration overrides.

Render and inspect this overlay before deployment. Confirm no credentials appear
in ConfigMaps or rendered manifests.

### 8. Deploy the Isolated Pilot

```bash
helm dependency build charts/kodus/kodus

helm upgrade --install kodus charts/kodus/kodus \
  --namespace kodus-pilot \
  --create-namespace \
  --values charts/kodus/kodus/values-pilot.example.yaml \
  --values /path/to/private-values.yaml
```

Validate:

- Migration Job completion.
- All application Pods.
- PVCs.
- Services and EndpointSlices.
- Ingress and TLS.
- API, web, and webhook health endpoints.
- Secret synchronization.
- NetworkPolicy behavior.
- `helm test`.

### 9. Create GitHub Integrations

Create the GitHub App with the minimum documented permissions for:

- Repository metadata/read access.
- Repository contents/read access.
- Pull request review/comment operations.
- Webhook delivery.

Configure:

```text
Homepage URL:
  https://<kodus-web-host>

Callback URL:
  https://<kodus-web-host>/api/auth/callback/github

Setup URL:
  https://<kodus-web-host>/setup/github

Webhook URL:
  https://<kodus-webhooks-host>/github/webhook
```

Store the App ID, client secret, private key, and installation URL through the
approved Secret workflow.

Separately decide whether a GitHub OAuth App is required for user login. If yes,
configure its callback and credentials independently from the GitHub App.

### 10. Configure Kodus Rules and Jira Context

Start with:

- Organization styleguides.
- `AGENTS.md` guidance.
- Quality-gate conventions.
- Security rules.
- Testing and architecture rules.
- Jira acceptance criteria.

Choose between:

- UI-managed rules.
- Repository-local `.kody-rules`.
- Centralized Kodus configuration repository.

Connect Jira through the Kodus plugin before enabling automatic business-logic
validation.

### 11. Run Acceptance Tests

Use one pilot repository and two pull requests:

- A compliant pull request.
- A deliberately non-compliant pull request with a safe, known violation.

Record:

- Webhook delivery status.
- Queue processing.
- Review latency.
- Provider/model response.
- Useful findings.
- False positives.
- Duplicate comments.
- Failed/retried reviews.
- Deterministic quality-gate status.

### 12. Production Hardening and Ownership

Before production:

- Replace bundled datastores with external/operator-managed services.
- Enable backups and restore testing.
- Use Infisical or approved ExternalSecrets.
- Configure Secret rotation and rollout procedures.
- Restrict ingress-controller labels in NetworkPolicies.
- Restrict egress where practical.
- Keep JSON logs and centralize them.
- Monitor queue depth, worker failures, PVCs, API health, webhook delivery,
  and provider errors.
- Document model changes, key rotation, rollback, and incident ownership.
- Back up databases before upgrades because Helm rollback does not reverse
  migrations.
- Enforce restricted Pod Security Standards/OpenShift SCC.
- Decide whether Kodus remains advisory or becomes merge-blocking.

## Inputs Needed Before Execution

- Actual pilot cluster and namespace.
- Three DNS names.
- Ingress controller and TLS issuer.
- Infisical project/environment/path and authentication Secret.
- Datastore strategy.
- GitHub organization and pilot repository.
- GitHub App/OAuth ownership.
- Bifrost virtual-key path.
- Telemetry decision.
- Advisory versus merge-blocking policy.
