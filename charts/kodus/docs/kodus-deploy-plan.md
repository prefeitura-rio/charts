# Kodus Deployment Plan

## Key Corrections To The Plan

Reading the actual `deployment.yaml` template (lines 73-85) revealed how secrets are injected:

```yaml
envFrom:
  - configMapRef:
      name: kodus-config          # ALL global.config keys become env vars

env:
  # explicit individual valueFrom.secretKeyRef entries for:
  - dbEnv: API_PG_DB_*, API_MG_DB_*, API_PG_DB_PASSWORD, API_MG_DB_PASSWORD
  - rabbitmqEnv: API_RABBITMQ_URI (from existingSecret, key defaults to "uri")
  - appSecretsEnv: 6 required + optional cryptographic secrets
```

There is no `envFrom: secretRef` for the whole `existingSecret`. Only explicitly listed keys are pulled from the Secret. This means GitHub App credentials (`API_GITHUB_CLIENT_SECRET`, `API_GITHUB_PRIVATE_KEY`, `WEB_OAUTH_GITHUB_CLIENT_SECRET`) are not handled by any secret template and fall through to `global.config` (ConfigMap).

### Confirmed RabbitMQ Vhost

From `_env.tpl` line 113:

```text
amqp://$(RABBITMQ_USER):$(RABBITMQ_PASS)@{{ .Release.Name }}-rabbitmq:5672/kodus-ai
```

The vhost is definitively `kodus-ai`. The external URI key defaults to `uri` (line 132). We will override it to `API_RABBITMQ_URI` for clarity.

## Updated Final Plan

### Phase 1: Chart, Release Workflow Fix Only

The nested structure (`charts/kodus/kodus/`) stays exactly as is. Only `.github/workflows/release.yaml` gets a path resolution step.

After the chart output is set, before the version bump, add:

```yaml
- name: Resolve chart directory
  id: resolve
  run: |
    CHART=${{ steps.chart.outputs.chart }}
    DIR="charts/$CHART"
    # Handle nested layout: charts/kodus/kodus/ has no Chart.yaml at top level
    if [ ! -f "$DIR/Chart.yaml" ] && [ -f "$DIR/$CHART/Chart.yaml" ]; then
      DIR="$DIR/$CHART"
    fi
    echo "chart_dir=$DIR" >> "$GITHUB_OUTPUT"
```

All subsequent steps replace `charts/${{ steps.chart.outputs.chart }}` with `${{ steps.resolve.outputs.chart_dir }}`. Everything else in the workflow stays unchanged.

After merge to main, CI auto-bumps to `v0.2.4` and publishes:

```text
oci://ghcr.io/prefeitura-rio/charts/kodus:0.2.4
```

### Phase 2: Variables And Secrets (SOPS)

Both `variables.tf` files, the root file and `modules/deployments/variables.tf`, get:

```hcl
variable "kodus" {
  description = "Kodus AI PR review platform configuration"
  sensitive   = true
  type = object({
    postgres = object({
      username = optional(string, "kodus")
      password = string
    })
    mongodb = object({
      username = optional(string, "kodus")
      password = string
    })
    rabbitmq = object({
      username = optional(string, "kodus")
      password = string
    })
    github = object({
      app_id              = string
      install_url         = string
      oauth_client_id     = string
      client_secret       = string
      private_key         = string # multiline PEM
      oauth_client_secret = string
    })
    secrets = object({
      jwt_secret             = string
      jwt_refresh_secret     = string
      nextauth_secret        = string
      api_crypto_key         = string # hex32
      code_management_secret = string # hex32
      open_ai_api_key        = optional(string, "") # BYOK pending
    })
  })
}
```

`terraform.tfvars.sops.json` will be edited if possible. If SOPS encryption blocks programmatic editing, the required JSON block will be provided for manual entry.

### Phase 3: `modules/deployments/kodus.tf`

#### Secret Distribution

The `kodus-secrets` Kubernetes Secret holds cryptographic keys, database passwords, and the RabbitMQ URI:

| Key | Value |
|---|---|
| `API_JWT_SECRET` | `var.kodus.secrets.jwt_secret` |
| `API_JWT_REFRESH_SECRET` | `var.kodus.secrets.jwt_refresh_secret` |
| `WEB_NEXTAUTH_SECRET` | `var.kodus.secrets.nextauth_secret` |
| `NEXTAUTH_SECRET` | `var.kodus.secrets.nextauth_secret` |
| `API_CRYPTO_KEY` | `var.kodus.secrets.api_crypto_key` |
| `CODE_MANAGEMENT_SECRET` | `var.kodus.secrets.code_management_secret` |
| `API_PG_DB_PASSWORD` | `var.kodus.postgres.password` |
| `API_MG_DB_PASSWORD` | `var.kodus.mongodb.password` |
| `API_RABBITMQ_URI` | `amqp://kodus:{password}@kodus-rabbitmq.kodus.svc.cluster.local:5672/kodus-ai` |
| `API_OPEN_AI_API_KEY` | `var.kodus.secrets.open_ai_api_key` (empty until BYOK is ready) |

The `global.config` ConfigMap contains only non-sensitive GitHub configuration
sourced from SOPS variables:

```text
NEXTAUTH_URL                       = "https://kodus.{tailscale.domain}"
API_OPENAI_FORCE_BASE_URL          = "https://bifrost.{domain}/openai/v1"
API_LLM_PROVIDER_MODEL             = "Huawei/deepseek-v4-flash"
API_GITHUB_CODE_MANAGEMENT_WEBHOOK = "https://webhooks.kodus.{domain}/github/webhook"
API_GITHUB_APP_ID                  = var.kodus.github.app_id
WEB_GITHUB_INSTALL_URL             = var.kodus.github.install_url
WEB_OAUTH_GITHUB_CLIENT_ID         = var.kodus.github.oauth_client_id
```

The sensitive GitHub values are stored in `kodus-secrets` and injected through
`secretKeyRef`:

```text
API_GITHUB_CLIENT_SECRET
API_GITHUB_PRIVATE_KEY
WEB_OAUTH_GITHUB_CLIENT_SECRET
```

The GitHub values remain placeholders until the GitHub App and OAuth App are created together in Phase 5.

#### Resources In `kodus.tf`

1. `kubernetes_namespace_v1.kodus`
   - Labels: `istio-injection=enabled`

2. `kubernetes_secret_v1.kodus_secrets`
   - Depends on the Kodus namespace.

3. `helm_release.kodus_postgres` using CloudPirates PostgreSQL `v0.20.6`
   - OCI chart: `oci://registry-1.docker.io/cloudpirates/postgres`
   - Image: `pgvector/pgvector:pg16`
   - `auth.username = var.kodus.postgres.username`
   - `auth.database = "kodus_db"`
   - `auth.existingSecret = "kodus-secrets"`
   - `auth.secretKeys.adminPasswordKey = "API_PG_DB_PASSWORD"`
   - `config.postgresql.shared_preload_libraries = "vector"`
   - InitDB script: `CREATE EXTENSION IF NOT EXISTS vector;`
   - Persistence size: `10Gi`
   - Depends on `kodus_secrets`.

4. `helm_release.kodus_mongodb` using CloudPirates MongoDB `v0.18.15`
   - OCI chart: `oci://registry-1.docker.io/cloudpirates/mongodb`
   - `auth.rootUsername = var.kodus.mongodb.username`
   - `auth.existingSecret = "kodus-secrets"`
   - `auth.existingSecretPasswordKey = "API_MG_DB_PASSWORD"`
   - Persistence size: `10Gi`
   - Depends on `kodus_secrets`.

5. `helm_release.kodus_rabbitmq` using CloudPirates RabbitMQ `v0.21.28`
   - OCI chart: `oci://registry-1.docker.io/cloudpirates/rabbitmq`
   - Image registry: `ghcr.io`
   - Image repository: `kodustech/kodus-rabbitmq`
   - Image tag: `4.2.2-kodus`
   - `auth.username = var.kodus.rabbitmq.username`
   - `auth.existingSecret = "kodus-secrets"`
   - `auth.existingPasswordKey = "RABBITMQ_PASS"`
   - Definitions enabled with vhosts `kodus-ai` and `kodus-ast`.
   - Permissions for user `kodus` on both vhosts: configure `.*`, write `.*`, read `.*`.
   - Persistence size: `5Gi`
   - Depends on `kodus_secrets`.

6. `helm_release.kodus` using Kodus chart `v0.2.4`
   - OCI chart: `oci://ghcr.io/prefeitura-rio/charts/kodus`
   - Depends on `kodus_postgres`, `kodus_mongodb`, `kodus_rabbitmq`, and `kodus_secrets`.
   - `imageTag = "2.1.31"`
   - `platform = "kubernetes"`
   - `global.existingSecret = "kodus-secrets"`
   - `global.labels` includes `kodus.io/environment=prod`, `kodus.io/team=iplanrio`, and related deployment labels.
   - PostgreSQL uses external mode:
     - Host: `kodus-postgres.kodus.svc.cluster.local`
     - Port: `5432`
     - Database: `kodus_db`
     - Username: `var.kodus.postgres.username`
     - Existing secret: `kodus-secrets`
     - Password key: `API_PG_DB_PASSWORD`
     - SSL mode: `disable`
   - MongoDB uses external mode:
     - Host: `kodus-mongodb.kodus.svc.cluster.local`
     - Port: `27017`
     - Database: `kodus_db`
     - Username: `var.kodus.mongodb.username`
     - Existing secret: `kodus-secrets`
     - Password key: `API_MG_DB_PASSWORD`
   - RabbitMQ uses external mode:
     - Existing secret: `kodus-secrets`
     - URI key: `API_RABBITMQ_URI`
   - `ingress.enabled = false`
   - `services.mcp-manager.enabled = false`
   - `services.worker-analytics.enabled = false`
   - `services.web.replicas = 1`
   - `services.api.replicas = 1`
   - `services.worker.replicas = 1`
   - `services.webhooks.replicas = 1`
   - `autoscaling.enabled = false`
   - `pdb.enabled = false` for the single-replica pilot.

7. `kubectl_manifest.kodus_tailscale_web`
   - Tailscale Ingress with hostname `kodus` targeting `kodus-web:3000`.

8. `kubectl_manifest.kodus_tailscale_api`
   - Tailscale Ingress with hostname `kodus-api` targeting `kodus-api:3001`.

9. `kubectl_manifest.kodus_webhooks_virtual_service`
   - Istio VirtualService for `webhooks.kodus.{var.domain}`.
   - Uses `local.gateway_name` for the Istio Gateway reference.
   - Routes to `kodus-webhooks.kodus.svc.cluster.local:3332`.
   - Timeout: `30s`.

#### RabbitMQ Password Secret Key

The CloudPirates chart uses the key configured by `auth.existingPasswordKey` to bootstrap the RabbitMQ admin password. Therefore `kodus-secrets` must also contain:

```text
RABBITMQ_PASS = var.kodus.rabbitmq.password
```

### Phase 5: Together After Manual Apply

Do not create these resources automatically. After the infrastructure has been manually reviewed and applied, complete the following together:

1. Create a GitHub App using https://docs.kodus.io/how_to_deploy/en/platforms/github/github_app.md.
2. Create a GitHub OAuth App using https://docs.kodus.io/how_to_deploy/en/platforms/github/github_oauth.md.
3. Add the resulting credentials to `terraform.tfvars.sops.json`.
4. Create the Bifrost virtual key for GPT LUNA and set it as `API_OPEN_AI_API_KEY`.
5. Configure the webhook URL in the GitHub App.

## Operational Constraints

- Do not merge, push, or apply anything without manual confirmation.
- Do not create GitHub Apps, Bifrost virtual keys, or other external resources solo.
- Charts repository branch: `feature/add-kodus-chart`.
- Iplan repository branch: `feat/kodus-deploy`.
- Preserve the intentional nested chart layout: `charts/kodus/kodus/` and `charts/kodus/kodus-common/`.
- Use SOPS in `terraform.tfvars.sops.json`; do not use Infisical.
- Use CloudPirates charts for all three datastores.
- Do not use `local.postgres_host` for Kodus; Kodus uses its own CloudPirates PostgreSQL.
- Use `local.gateway_name` for the Istio VirtualService.
- Web UI and API are Tailscale-only; only the webhook endpoint is publicly exposed through Istio.
- Deploy without `API_OPEN_AI_API_KEY` until the Bifrost virtual key exists.
- Keep `mcp-manager` and `worker-analytics` disabled for the initial community deployment.

## Repository Context

- Main chart: `/home/vitor/Projects/resources/charts/charts/kodus/kodus/` (currently `v0.2.3`).
- Shared chart: `/home/vitor/Projects/resources/charts/charts/kodus/kodus-common/`.
- Environment helpers: `/home/vitor/Projects/resources/charts/charts/kodus/kodus-common/templates/_env.tpl`.
- Deployment template: `/home/vitor/Projects/resources/charts/charts/kodus/kodus/templates/deployment.yaml`.
- Release workflow: `/home/vitor/Projects/resources/charts/.github/workflows/release.yaml`.
- Terraform reference: `/home/vitor/Projects/infra/iplan/modules/deployments/bifrost.tf`.
- Tailscale reference: `/home/vitor/Projects/infra/iplan/modules/deployments/tailscale.tf`.
- Istio reference: `/home/vitor/Projects/infra/iplan/modules/deployments/istio.tf`.
- Cloud SQL reference: `/home/vitor/Projects/infra/iplan/modules/deployments/cloudsql-proxy.tf`.
- Deployment variables: `/home/vitor/Projects/infra/iplan/modules/deployments/variables.tf`.
- Root variables: `/home/vitor/Projects/infra/iplan/variables.tf`.
- Encrypted variables: `/home/vitor/Projects/infra/iplan/terraform.tfvars.sops.json`.
- CloudPirates usage reference: `/home/vitor/Projects/infra/iplan/modules/deployments/prefect.tf`.
- Project guide: `/home/vitor/Projects/kodus_helm_guide.md`.
- Jira task: `INFRAVPIA-268`.

## Next Implementation Steps

1. Fix `.github/workflows/release.yaml` to resolve the nested Kodus chart directory and propagate `chart_dir` to downstream steps.
2. Run local chart validation without pushing:
   - `helm dependency build charts/kodus/kodus/`
   - `helm lint charts/kodus/kodus/`
   - `helm unittest charts/kodus/kodus/`
3. Draft `modules/deployments/kodus.tf` with the resources listed above.
4. Add the `kodus` variable to the root and deployments-module `variables.tf` files.
5. Attempt the `terraform.tfvars.sops.json` update. If SOPS prevents programmatic editing, stop and provide the exact block for manual entry.
6. Review Terraform formatting and validation. Do not run `terraform apply`.
7. Report any chart publication or external-resource prerequisites that require manual action.

## Decision Update: Private Exposure, GPT LUNA, And Datastore Resources

This section supersedes the earlier DeepSeek and public-web exposure assumptions.

### Private Exposure Model

Everything Kodus-related remains private except the webhook endpoint required by
external providers such as GitHub:

| Function | Exposure |
|---|---|
| Kodus web UI | Tailscale only |
| Kodus API | Tailscale only |
| PostgreSQL | Cluster-internal only |
| MongoDB | Cluster-internal only |
| RabbitMQ | Cluster-internal only |
| GitHub webhook | Public Istio endpoint only |

Keep the Tailscale hosts:

```text
kodus.<tailscale-domain>      -> kodus-web:3000
kodus-api.<tailscale-domain>  -> kodus-api:3001
```

Do not create public VirtualServices for the Kodus web UI or API. The only public
VirtualService is:

```text
kodus-webhooks.iplan.dados.rio
    -> kodus-webhooks.kodus.svc.cluster.local:3332
```

`NEXTAUTH_URL` must use the private Tailscale web hostname, not
`kodus.iplan.dados.rio`, because the web UI is not publicly exposed.

### GPT LUNA Configuration

The Kodus ConfigMap must contain:

```text
API_OPENAI_FORCE_BASE_URL=https://bifrost.iplan.dados.rio/openai/v1
API_LLM_PROVIDER_MODEL=openai.gpt-5.6-luna
NEXTAUTH_URL=https://kodus.<tailscale-domain>
API_GITHUB_CODE_MANAGEMENT_WEBHOOK=https://kodus-webhooks.iplan.dados.rio/github/webhook
```

`API_OPEN_AI_API_KEY` remains empty until the Bifrost virtual key is created. It
is stored in the SOPS-backed Kubernetes Secret rather than the ConfigMap.

### Storage Decision

Keep the existing storage values unchanged:

```text
PostgreSQL: 10Gi
MongoDB:    10Gi
RabbitMQ:    5Gi
```

No PVC resize or storage migration is part of this change.

### Datastore Resource Requests And Limits

The CloudPirates charts currently inherit empty resource requests and limits. Add
explicit values to the three datastore Helm releases:

| Datastore | Requests | Limits |
|---|---|---|
| PostgreSQL | `250m CPU`, `512Mi` | `1 CPU`, `1Gi` |
| MongoDB | `100m CPU`, `512Mi` | `500m CPU`, `1Gi` |
| RabbitMQ | `100m CPU`, `256Mi` | `500m CPU`, `1Gi` |

These are pilot baselines based on the existing PostgreSQL and RabbitMQ
deployments, CloudPirates recommendations, and the single-replica Kodus setup.
They are scheduling guarantees and boundaries, not measurements of actual peak
usage. They must be reviewed after observing the deployed workloads.

The current Kodus application requests approximately `950m` CPU and `2.4Gi`
memory for the single-replica web, API, worker, webhooks, and migration workload.
Adding the datastore requests gives an estimated baseline of approximately
`1.4` CPU and `3.7Gi` memory, excluding Kubernetes system overhead.

### Updated Implementation Steps

1. Update `modules/deployments/kodus.tf` with the GPT LUNA values, private
   `NEXTAUTH_URL`, and the new public webhook hostname.
2. Preserve the Tailscale web and API entries in `modules/deployments/tailscale.tf`.
3. Keep the webhook-only Istio VirtualService and do not add public UI/API routes.
4. Add the approved `resources.requests` and `resources.limits` blocks to the
   PostgreSQL, MongoDB, and RabbitMQ Helm values.
5. Keep all three existing PVC sizes unchanged.
6. After GCP authentication is restored, update the SOPS variables with the empty
   `open_ai_api_key` and remaining required Kodus values.
7. Run formatting, OpenTofu validation, TFLint, Helm lint, and Helm rendering.
8. Inspect cluster node capacity, StorageClasses, quotas, and existing PVC usage
   before any manual `tofu apply`.
9. Do not merge, push, apply, create the GitHub App, or create the Bifrost key
   without explicit manual confirmation.

### Implementation Status

- The decision update has been implemented in `modules/deployments/kodus.tf`.
- The existing PVC sizes remain unchanged.
- GitHub sensitive credentials are now injected through `secretKeyRef`; only
  non-sensitive GitHub settings remain in the ConfigMap.
- The Kodus Helm release now waits for migration Jobs with `wait_for_jobs = true`.
- The deployments module validates successfully with OpenTofu.
- Helm lint and external-mode rendering pass.
- Local `helm unittest` execution is currently blocked by pre-existing
  `document not found` failures in deployment-oriented suites under Helm
  `v4.2.3`; the service, PDB, and ConfigMap suites pass.
- SOPS editing remains blocked until GCP credentials are reauthenticated; no
  encrypted values were changed.

## Follow-Up Findings And Execution Notes

### Existing GitHub App

The existing encrypted variables file already contains a GitHub App structure:

```text
github.app.id
github.app.installation_id
github.app.private_key
```

These values are currently consumed by Argo CD in
`modules/deployments/argo-cd.tf`. They are not automatically sufficient for
Kodus. Kodus also requires an App client secret and installation URL, and GitHub
OAuth login requires a separate OAuth client ID and secret.

Before creating another App, verify the existing App in GitHub:

- The App ID matches `github.app.id`.
- The installation targets the intended organization and pilot repository.
- Contents permission is read-only.
- Pull requests, Issues, and Checks permissions are read/write where required.
- Metadata permission is read-only.
- Pull request, pull request review comment, issue comment, and push events are enabled.
- The App webhook can use `https://kodus-webhooks.iplan.dados.rio/github/webhook`.
- The App client secret is available.
- The installation URL is available.
- Reusing the App will not unintentionally change Argo CD behavior or ownership.

The existing Argo CD value is base64-decoded before use. Kodus expects the raw
PEM private-key contents, so the existing key must be decoded before it is put
into the Kodus secret.

### Manual SOPS Procedure

The `kodus` object is still absent from
`/home/vitor/Projects/infra/iplan/terraform.tfvars.sops.json`. SOPS must be
updated manually after GCP authentication is restored:

```bash
gcloud auth login
gcloud auth application-default login
cd /home/vitor/Projects/infra/iplan
sops terraform.tfvars.sops.json
```

Add a top-level `kodus` object containing PostgreSQL, MongoDB, RabbitMQ, GitHub,
and application secret values. Use the existing GitHub App values only after
the verification above. Set `open_ai_api_key` to an empty string until the
Bifrost virtual key exists. Do not paste `ENC[...]` ciphertext into the new
object; SOPS re-encrypts the plaintext when the editor is saved.

Required formats:

- `api_crypto_key`: exactly 64 hexadecimal characters.
- `code_management_secret`: exactly 64 hexadecimal characters.
- `nextauth_secret`: one high-entropy value mirrored to both NextAuth secrets.
- GitHub private key: raw multiline PEM, not the Argo CD base64 representation.

Verify the result without printing secrets:

```bash
sops --decrypt --input-type json --output-type json terraform.tfvars.sops.json >/dev/null
```

### Migration Job Waiting

Kodus migrations run as a normal Kubernetes Job. Helm `wait = true` does not
necessarily wait for that Job to complete. The Kodus Helm release should also
set `wait_for_jobs = true`, so a failed migration causes the release to fail
instead of reporting a ready deployment with an incomplete database.

After deployment, still inspect the Job and logs explicitly:

```bash
kubectl get jobs -n kodus
kubectl logs job/<migration-job> -n kodus
```

### Target Cluster

The confirmed target kubeconfig context is:

```text
gke_rj-iplanrio-dia_us-central1_iplanrio-infra
```

The Terraform cluster is `iplanrio-infra` in the `rj-iplanrio-dia` project and
the current namespace is `kodus`. Any documentation referring to another
cluster or `kodus-pilot` must be treated as stale or explicitly marked as an
example.

### Production Hardening

Production hardening is tracked separately in
`/home/vitor/Projects/kodus-pre-prod-hardening.md`. It covers datastore
resilience, secret rotation, network security, availability, monitoring,
upgrades, ownership, and review policy. The current deployment remains a
single-replica bundled-datastore pilot until that checklist is completed.
