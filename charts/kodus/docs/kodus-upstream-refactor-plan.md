# Kodus Upstream Chart Refactor Plan

## Purpose

Remove the locally forked Kodus Helm chart and consume the upstream OCI chart
directly. Preserve the deployment behavior currently required by Iplan through
Terraform-managed resources and a Helm post-renderer instead of maintaining
Kodus chart templates in this repository.

This document is a plan only. No chart, Terraform, cluster, GitHub, Bifrost, or
secret changes should be made until this plan is approved.

## Target State

The final deployment will:

- Consume the upstream Kodus OCI chart directly from the upstream registry.
- Remove `charts/kodus/kodus/` and `charts/kodus/kodus-common/` from this chart repository.
- Keep Kodus deployment-specific configuration in `/home/vitor/Projects/infra/iplan`.
- Use a small Python Helm post-renderer to inject GitHub credentials as
  `secretKeyRef` entries into the rendered Kodus workloads.
- Disable the upstream chart's NetworkPolicy resources.
- Manage the required NetworkPolicies explicitly through Terraform.
- Automatically trigger a Kodus rollout when any secret used by Kodus changes,
  using a Terraform-derived hash placed in the chart ConfigMap.
- Preserve the current private/public exposure model:
  - Web UI: Tailscale only.
  - API: Tailscale only.
  - Webhooks: public Istio endpoint only.
  - Datastores: cluster-internal only.
- Keep external PostgreSQL, MongoDB, and RabbitMQ managed by the existing
  CloudPirates Helm releases.
- Keep `mcp-manager` and `worker-analytics` disabled for the initial deployment.
- Keep the initial review policy advisory-only.

## Current Customizations To Replace

The local chart currently contains four relevant functional customizations:

1. GitHub credential injection in `kodus-common/templates/_env.tpl`.
2. Multiple NetworkPolicy ingress sources for Tailscale and Istio.
3. A `global.secretVersion`-based secret checksum in `deployment.yaml`.
4. Configurable egress rules.

The refactor replaces them as follows:

| Current customization | Replacement |
|---|---|
| GitHub secret references in chart helper | Python Helm post-renderer |
| Tailscale plus Istio ingress sources | Terraform-managed NetworkPolicies |
| `global.secretVersion` checksum | Automatic Terraform-derived ConfigMap hash |
| Configurable chart egress rules | Explicit Terraform policy, initially open egress unless a restricted policy is designed and tested |

Other local drift must not be carried forward unless it is explicitly required
by the deployment and represented as Terraform values. This includes comment
cleanup, bundled-datastore hardening, the RabbitMQ password guard, ExternalSecret
prefix customization, and chart-default changes such as JWT TTL or PostgreSQL
SSL behavior.

## Repository Responsibilities

### Charts repository

After the refactor, the charts repository should retain the Kodus documentation
under `charts/kodus/docs/`, including this plan, but should no longer contain a
Kodus chart or Kodus chart release artifacts.

Expected removal:

```text
charts/kodus/kodus/
charts/kodus/kodus-common/
```

The charts release workflow must be reviewed so it no longer discovers,
packages, versions, or publishes the removed local Kodus chart.

### Iplan infrastructure repository

The Iplan repository becomes the owner of:

- The upstream `helm_release.kodus` configuration.
- The post-renderer script.
- Terraform-managed Kodus NetworkPolicies.
- The derived secret-rotation hash.
- Rendered-manifest validation and deployment documentation.

The expected new script location is:

```text
/home/vitor/Projects/infra/iplan/modules/deployments/files/kodus/kodus-postrender.py
```

The exact location may be adjusted if the repository has a stronger convention,
but the path must be stable because the Helm provider executes it locally.

## Phase 0: Confirm Upstream Inputs

Before editing Terraform, verify the exact upstream chart coordinates and
release contents.

1. Confirm the upstream OCI registry, chart name, and version.
2. Pull the exact version locally with `helm pull`.
3. Inspect its `Chart.yaml`, values schema, Deployment templates, migration Job,
   labels, service names, and NetworkPolicy behavior.
4. Confirm that the upstream chart supports all currently used values:
   - External PostgreSQL.
   - External MongoDB.
   - External RabbitMQ.
   - Existing application Secret.
   - Disabled services.
   - Single replicas.
   - Disabled autoscaling and PDB.
   - `wait_for_jobs` at the Terraform Helm release level.
5. Confirm the upstream chart's published dependency packaging is complete and
   does not require the local `kodus-common` chart.
6. Render the upstream chart with the current deployment values before changing
   the live Terraform configuration.

The upstream coordinates must not be guessed. The implementation should use the
coordinates verified in this phase, for example:

```hcl
repository = "oci://<verified-upstream-registry>"
chart      = "kodus"
version    = "<verified-version>"
```

## Phase 1: Implement the Helm Post-Renderer

### Objective

Add the three GitHub-related secret references that the upstream chart does not
currently inject:

```text
API_GITHUB_CLIENT_SECRET
API_GITHUB_PRIVATE_KEY
WEB_OAUTH_GITHUB_CLIENT_SECRET
```

The script must inject references, never secret values.

### Required behavior

The script should:

1. Read Helm's multi-document YAML from standard input.
2. Parse YAML using `yaml.safe_load_all`, never an unsafe YAML loader.
3. Process only supported workload kinds, initially `Deployment` and any
   migration `Job` that requires the same application credentials.
4. Locate every application container in the workload.
5. Add the three `secretKeyRef` entries only when the environment variable is
   absent.
6. Use the configured existing Secret name, passed as a command-line argument
   or another explicit configuration mechanism, rather than silently relying on
   a hardcoded name.
7. Preserve `optional: true` to match the current chart behavior.
8. Leave all unrelated Helm documents unchanged semantically.
9. Write valid multi-document YAML to standard output.
10. Exit non-zero on malformed input, an unexpected workload structure, or an
    invalid configuration argument.

The implementation should be idempotent: running it twice must not duplicate
environment entries.

### Recommended script interface

Use an interface equivalent to:

```text
kodus-postrender.py --secret-name kodus-secrets
```

The Terraform Helm provider `postrender` configuration must pass this argument
if the installed provider version supports post-renderer arguments. If provider
support is insufficient, use a small repository-local executable wrapper that
sets the validated secret name before invoking the Python implementation. Do
not embed the secret value in the script or wrapper.

### Dependency handling

The execution environment must provide Python 3 and PyYAML. This dependency
must be made explicit and reproducible rather than relying on an incidental
developer workstation installation.

Preferred options, in order:

1. Use the existing project development environment if it already pins PyYAML.
2. Add a small documented virtual environment/bootstrap command for the Iplan
   repository.
3. Run the post-renderer from a pinned container image if Terraform execution is
   standardized in a container.

Do not silently download packages during `tofu apply`.

### Security requirements

- Use `yaml.safe_load_all` and safe dumping only.
- Never log stdin, stdout, rendered manifests, or secret values.
- Never load secret values from environment variables merely to write them into
  manifests.
- Add only `secretKeyRef` metadata.
- Keep the script under normal code review and branch protection.
- Add tests for duplicate prevention, malformed YAML, non-workload documents,
  missing containers, and correct Secret/key references.

## Phase 2: Refactor the Kodus Helm Release

Update `modules/deployments/kodus.tf` to consume the verified upstream OCI
chart directly.

### Remove the local registry dependency

Replace the locally published chart reference:

```hcl
repository = "oci://ghcr.io/prefeitura-rio/charts"
chart      = "kodus"
```

with the verified upstream repository and chart coordinates.

Keep the application version pinned. Do not use an unbounded tag or a floating
`latest` equivalent.

### Add the post-renderer

The Helm release must include a `postrender` block that executes the script from
the infrastructure repository. The exact provider syntax must be confirmed
against the installed Helm provider version before implementation.

Conceptually:

```hcl
postrender {
  binary_path = "${path.module}/kodus-postrender.py"
  args        = ["--secret-name", kubernetes_secret_v1.kodus_secrets.metadata[0].name]
}
```

The final configuration must use the provider-supported syntax and must be
tested with `tofu plan` and a local Helm render.

### Preserve deployment values

Retain the values required by the Iplan deployment, including:

- `global.existingSecret = "kodus-secrets"`.
- Private `NEXTAUTH_URL`.
- Bifrost base URL.
- `openai.gpt-5.6-luna` model identifier.
- Public webhook URL at `/github/webhook`.
- External datastore modes and credentials.
- Disabled Ingress resources from the chart.
- Disabled `mcp-manager` and `worker-analytics`.
- Single replicas for the pilot.
- Disabled autoscaling and PDB.
- `wait_for_jobs = true`.

Move any values currently obtained only from the fork's defaults into explicit
Terraform values. Do not depend on local default changes surviving the refactor.

## Phase 3: Manage NetworkPolicies in Terraform

Set the upstream chart's NetworkPolicy feature to disabled:

```hcl
networkPolicy = {
  enabled = false
}
```

Remove the fork-specific ingress values from the Helm values block.

Create explicit Terraform-managed NetworkPolicies after the Kodus Helm release.
The exact resource type should follow the repository convention, preferably
`kubectl_manifest` if that is already used for arbitrary Kubernetes resources.

### Required policy set

The initial policy set should preserve the current intended behavior:

1. **Default deny**
   - Select all Kodus application and bundled/operator-managed Kodus datastore
     Pods that are intended to be covered.
   - Deny ingress by default.
   - Keep egress open initially unless a complete restricted egress policy has
     been designed and tested.

2. **Intra-application allow**
   - Allow traffic between Pods carrying the Kodus release labels.
   - Verify that this covers the application-to-datastore traffic required by
     the selected external datastore topology, or explicitly scope the policy
     to application Pods only if external datastores are not selected by it.

3. **Web ingress**
   - Allow Tailscale-managed Pods in namespace `tailscale`.
   - Match `tailscale.com/managed: "true"`.
   - Allow TCP port `3000` only.

4. **API ingress**
   - Allow the same Tailscale source.
   - Allow TCP port `3001` only.

5. **Webhook ingress**
   - Allow Istio ingress gateway Pods in namespace `istio-system`.
   - Match `app: istio-ingressgateway`.
   - Allow TCP port `3332` only.

Use complete Kubernetes selector structures:

```yaml
namespaceSelector:
  matchLabels:
    kubernetes.io/metadata.name: tailscale
podSelector:
  matchLabels:
    tailscale.com/managed: "true"
```

A namespace selector and pod selector in the same peer are an AND condition.
Validate this behavior against the actual cluster labels before applying.

### NetworkPolicy validation

Before deployment:

- Render every policy and inspect selectors, ports, and policy types.
- Confirm no policy exposes the web or API through Istio.
- Confirm the public VirtualService still routes only to webhooks.
- Confirm Tailscale can reach web and API after policy application.
- Confirm GitHub can reach the webhook endpoint.
- Confirm application Pods can reach PostgreSQL, MongoDB, RabbitMQ, and Bifrost.
- Test both allowed and denied traffic where practical.

## Phase 4: Implement Automatic Secret-Rotation Rollouts

The upstream chart cannot hash the contents of an externally managed Secret.
Use the upstream chart's existing ConfigMap checksum annotation and make the
ConfigMap change automatically when the secret inputs change.

### Derived hash

In Terraform, calculate a deterministic hash from every value stored in
`kodus-secrets` that can affect Kodus Pods. Use a structured object and
`jsonencode`, not an ambiguous delimiter-based concatenation.

Conceptually:

```hcl
locals {
  kodus_secret_rotation_hash = sha256(jsonencode({
    api_jwt_secret                 = var.kodus.secrets.jwt_secret
    api_jwt_refresh_secret         = var.kodus.secrets.jwt_refresh_secret
    nextauth_secret                = var.kodus.secrets.nextauth_secret
    api_crypto_key                 = var.kodus.secrets.api_crypto_key
    code_management_secret         = var.kodus.secrets.code_management_secret
    open_ai_api_key                = var.kodus.secrets.open_ai_api_key
    github_client_secret           = var.kodus.github.client_secret
    github_private_key             = var.kodus.github.private_key
    github_oauth_client_secret     = var.kodus.github.oauth_client_secret
    postgres_password              = var.kodus.postgres.password
    mongodb_password               = var.kodus.mongodb.password
    rabbitmq_password              = var.kodus.rabbitmq.password
  }))
}
```

The exact field set must match the final `kubernetes_secret_v1.kodus_secrets`
data map. If a derived value such as `API_RABBITMQ_URI` changes when a source
password changes, the source password must still be included in the hash.

### ConfigMap trigger

Add only the derived hash to the Helm `global.config` map:

```hcl
KODUS_SECRET_ROTATION_HASH = local.kodus_secret_rotation_hash
```

The hash is not a secret and contains no raw credential material. It changes
automatically whenever an input secret changes. The upstream Deployment
template's `checksum/config` annotation then changes, causing Kubernetes to
roll the Pods after the updated Secret is applied.

The hash must not be truncated unless there is a concrete ConfigMap size or
provider limitation. The implementation must ensure the ConfigMap does not log
or expose the original secret values.

### Ordering and verification

- Keep the Helm release dependent on `kubernetes_secret_v1.kodus_secrets`.
- Confirm Terraform applies the Secret update before the Helm release rollout.
- Confirm the rendered ConfigMap contains only the hash value.
- Confirm Deployment `checksum/config` changes after a secret rotation.
- Confirm the new Pods read the rotated values.
- Confirm no manual revision bump is needed.

## Phase 5: Remove the Local Fork

After the upstream chart has been rendered and the replacement resources have
passed validation:

1. Remove `charts/kodus/kodus/`.
2. Remove `charts/kodus/kodus-common/`.
3. Remove the vendored `kodus-common` archive and local chart lock artifacts.
4. Review the chart release workflow and remove Kodus-specific packaging logic.
5. Keep the documentation under `charts/kodus/docs/` and update stale documents
   that still describe the local fork as the deployment source.
6. Update references that point to the local chart path or local registry.
7. Do not delete deployment documentation that remains useful for the upstream
   chart; revise its commands and ownership instead.

The deletion must be performed only after the infrastructure repository has the
upstream Helm release and post-renderer changes ready for review, so the chart
repository does not temporarily lose the only deployable artifact without a
replacement.

## Phase 6: Validation Before Any Apply

### Local chart and script validation

- Pull the exact upstream chart version.
- Run `helm lint` with the production values.
- Run `helm template` using the production-equivalent non-secret values.
- Pipe the render through the post-renderer.
- Verify the three GitHub `secretKeyRef` entries appear in the intended
  workloads and contain no literal secret values.
- Run the post-renderer twice and confirm the second output has no duplicates.
- Test malformed YAML and confirm the script exits non-zero.
- Run Terraform/OpenTofu formatting.
- Run Terraform/OpenTofu validation.
- Run `tofu plan` and inspect the Helm release, Secret, NetworkPolicy, and
  external resource changes.

### Rendered-manifest checks

Confirm that rendered output contains:

- The upstream chart version and image tag.
- No local chart dependency.
- No public web or API Ingress.
- The expected private and public hostnames.
- The expected GitHub secret references.
- No GitHub private key or other raw secret value.
- No chart-generated NetworkPolicies when disabled.
- The expected external datastore configuration.
- The secret-rotation hash only as a non-sensitive ConfigMap value.

### Security checks

- Run a repository search over rendered output for known secret values where
  safe and appropriate, without printing them in logs.
- Confirm no credentials are in ConfigMaps.
- Confirm the post-renderer does not log input or output.
- Confirm Terraform state handling remains protected because the Kubernetes
  Secret and source variables are sensitive.
- Confirm the post-renderer script is reviewed and executable only from the
  expected repository path.

## Phase 7: Controlled Deployment

Do not run `tofu apply` until the plan is approved and the rendered manifests
have been reviewed.

Deployment sequence:

1. Merge or otherwise stage the infrastructure changes according to the normal
   review process.
2. Authenticate to the confirmed cluster context:
   `gke_rj-iplanrio-dia_us-central1_iplanrio-infra`.
3. Run a fresh `tofu plan`.
4. Confirm the plan does not recreate persistent datastores or delete required
   data.
5. Apply the upstream Kodus release and Terraform-managed policies.
6. Inspect the migration Job and logs.
7. Inspect Pods, Services, EndpointSlices, and NetworkPolicies.
8. Verify Tailscale web and API access.
9. Verify public webhook TLS and exact path `/github/webhook`.
10. Verify GitHub delivery and Kodus webhook logs.
11. Verify RabbitMQ queue processing and worker activity.
12. Verify Bifrost model requests.
13. Run one compliant and one deliberately non-compliant pull request.
14. Record latency, findings, false positives, duplicates, retries, and errors.

## Rollback Plan

### Before apply

- Preserve the current Helm release revision and values.
- Back up PostgreSQL, MongoDB, and RabbitMQ according to the current policy.
- Export or record the existing NetworkPolicy definitions.
- Keep the local chart artifact available until the upstream deployment is
  accepted.

### Application rollback

- If the upstream chart fails before migration changes, restore the prior Helm
  release or redeploy the prior local artifact.
- If the migration Job changes the database schema, do not assume Helm rollback
  reverses migrations.
- Follow Kodus release notes and restore from database backup when required.
- Restore the prior NetworkPolicies only if the new policies cause a service
  outage and the old policies are known to be safe.

### Post-renderer rollback

- A post-renderer failure should fail the Helm release before manifests are
  accepted.
- Keep the previous script version available in version control.
- Revert the script and Helm release change together if the rendered workload
  structure changes unexpectedly.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Upstream chart changes workload structure | Pin versions, render before upgrades, test post-renderer against each version |
| Python/PyYAML unavailable | Pin and document the execution environment; fail early before apply |
| Secret name mismatch | Pass the Secret name explicitly and validate it in tests |
| GitHub env vars injected into an unintended workload | Target only approved workload kinds and verify rendered output |
| NetworkPolicy selector mismatch | Inspect actual namespace and Pod labels; test allowed paths before production |
| Secret rotation does not roll Pods | Test the derived hash and `checksum/config` change in a disposable namespace |
| Upstream defaults change | Set all production-critical values explicitly in Terraform |
| Helm rollback does not reverse migration | Back up databases and use the documented migration recovery process |
| Fork deletion happens before replacement is ready | Stage and review infrastructure changes before deleting chart files |

## Acceptance Criteria

The refactor is complete only when all of the following are true:

- Terraform references the verified upstream OCI chart directly.
- No Kodus chart or shared Kodus library chart remains in this repository.
- The post-renderer injects the required GitHub references without raw secrets.
- The post-renderer is deterministic and idempotent.
- NetworkPolicies are managed explicitly by Terraform and cover Tailscale and
  Istio correctly.
- A change to any managed Kodus secret automatically changes the ConfigMap hash
  and rolls the relevant Pods.
- Helm lint, rendering, post-renderer tests, and OpenTofu validation pass.
- The migration Job completes successfully.
- Web, API, webhook, datastore, queue, and Bifrost flows are verified.
- A compliant and a deliberately non-compliant pull request are recorded.
- The deployment remains advisory-only unless a separate policy approval changes
  that behavior.
- Documentation no longer presents the local fork as the deployment source.

## Approval Gate

Approval is required before implementation begins. In particular, confirm:

- The upstream OCI registry and chart version will be verified before coding.
- Python 3 plus a pinned PyYAML execution environment is acceptable.
- Terraform will own the Kodus NetworkPolicies.
- The derived secret hash may be placed in the Kodus ConfigMap.
- The local Kodus chart may be deleted after the replacement is validated.
- No `tofu apply`, chart publication, external resource creation, GitHub App
  change, or Bifrost key change is authorized by this document alone.
