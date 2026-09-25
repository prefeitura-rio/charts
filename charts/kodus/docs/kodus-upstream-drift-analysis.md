# Kodus Upstream Drift Analysis

Date: 2026-09-25

Status: Discussion document. This is an analysis of the local Kodus chart and
must not be treated as an implementation plan until the deployment model is
confirmed by the team.

## Purpose

The Kodus chart was copied from `kodustech/kodus-installer` instead of being
consumed directly as an OCI dependency. This document records:

- What the local deployment actually requires.
- Which local changes diverge from the upstream chart.
- Which changes are necessary, useful, unused, or questionable.
- Whether the remaining drift justifies maintaining a fork.

## Source And Local State

The local chart was imported from the Kodus installer snapshot associated with
source commit `674b02f17792052cbef20fe82285d9504056b69a`.

Local chart:

- Path: `charts/kodus/kodus/`
- Chart version: `0.2.3`
- Kodus application version: `2.1.31`
- Upstream source: `https://github.com/kodustech/kodus-installer`
- Local chart is a copy, not a submodule or dependency on the upstream chart.

The upstream repository later published chart version `0.2.4` as an OCI
artifact. There is no automatic synchronization between the repositories.

The large local diff is misleading. A substantial part of it consists of:

- Documentation added for the Iplan deployment.
- Comments removed from templates and values files.
- Unit tests added locally.

The meaningful runtime divergence is much smaller and is listed below.

## Deployment Model Required By Our Documentation

The local documentation describes two related but different models.

### Bundled pilot

The pilot runbook supports:

- Bundled PostgreSQL, MongoDB, and RabbitMQ.
- One isolated pilot namespace.
- A public webhook endpoint.
- Private web and API access through Tailscale, an internal ingress, or a port-forward.
- Advisory-only review behavior.

Primary document: `kodus-pilot-pr-review.md`.

### Iplan deployment

The later deployment plan and the Terraform implementation define the current
Iplan target:

- External PostgreSQL, MongoDB, and RabbitMQ, deployed separately with CloudPirates charts.
- Kodus uses `postgres.mode=external`, `mongodb.mode=external`, and `rabbitmq.mode=external`.
- A Terraform/SOPS-managed Kubernetes Secret named `kodus-secrets`.
- Web and API exposed privately through Tailscale.
- Webhooks exposed publicly through an Istio VirtualService.
- MCP manager and analytics worker disabled.
- Single replicas and autoscaling disabled for the pilot.
- Bifrost used as the OpenAI-compatible provider.
- NetworkPolicy enabled.
- Helm waits for the migration Job to complete.

Primary documents:

- `kodus-deploy-plan.md`
- `/home/vitor/Projects/infra/iplan/modules/deployments/kodus.tf`

The Iplan model is the relevant model when evaluating whether the local chart
fork is justified for the planned deployment.

## Secret Injection Finding

### Conclusion

For the current deployment, the local `_env.tpl` change is necessary.

The conclusion has one precise qualification: the credentials are not
universally impossible to inject without `_env.tpl`; they could be placed in a
ConfigMap or added through another post-rendering or admission mechanism. But
they are not injected from the existing Kubernetes Secret by the original
chart.

### Original chart behavior

The application Deployments use:

```yaml
envFrom:
  - configMapRef:
      name: kodus-config
```

They then include `kodus-common.appSecretsEnv` for explicit Secret references.

The original optional secret list included:

```text
CODE_MANAGEMENT_WEBHOOK_TOKEN
API_OPEN_AI_API_KEY
API_MORPHLLM_API_KEY
API_E2B_KEY
API_MCP_MANAGER_JWT_SECRET
API_MCP_MANAGER_ENCRYPTION_SECRET
```

It did not include:

```text
API_GITHUB_CLIENT_SECRET
API_GITHUB_PRIVATE_KEY
WEB_OAUTH_GITHUB_CLIENT_SECRET
```

The original chart does not use `envFrom.secretRef` for the complete
`global.existingSecret`. Therefore, merely putting those keys in
`kodus-secrets` does not expose them to the containers.

### Current Iplan behavior

Terraform creates those values in `kodus-secrets`:

```text
API_GITHUB_CLIENT_SECRET
API_GITHUB_PRIVATE_KEY
WEB_OAUTH_GITHUB_CLIENT_SECRET
```

The local `kodus-common/templates/_env.tpl` adds them to the optional
`secretKeyRef` list. That allows the API and web containers to receive the
credentials without putting them in `global.config` or a ConfigMap.

This is a strong justification for local template divergence.

The changes in `secrets.yaml` and `externalsecret.yaml` are separate concerns:

- They matter when the chart creates or synchronizes the Secret itself.
- They are not required for the current Terraform `global.existingSecret` path.

## NetworkPolicy Model

The local chart creates these policy layers when `networkPolicy.enabled=true`:

### Default policy

`<release>-default-deny` selects all Pods belonging to the Kodus release.

- Ingress is denied initially.
- Egress is currently open with `- {}`.
- If `networkPolicy.egressRules` is supplied, it replaces the open egress rule.

### Intra-application policy

`<release>-allow-intra-app` allows Kodus Pods in the same namespace and release
to communicate with one another. This covers application-to-datastore and
application-to-application traffic for Pods carrying the expected Kodus labels.

### External ingress policies

Separate policies are created for the web, API, and webhooks Pods. They allow
only the service port for each selected workload.

The intended Iplan traffic is:

```text
Tailscale proxy Pod in namespace tailscale
  -> kodus-web or kodus-api Service
  -> Kodus web or API Pod

Istio ingress gateway Pod in namespace istio-system
  -> kodus-webhooks Service
  -> Kodus webhooks Pod
```

The Tailscale operator source confirms that generated proxy Pods use the
`tailscale.com/managed=true` label. The Iplan Istio gateway uses
`app=istio-ingressgateway`.

The `additionalIngressSources` concept is therefore meaningful and required
for the intended Tailscale-plus-Istio topology. The upstream chart only models
one ingress source.

### Egress restriction behavior

`egressRules` is an extension point, not an active restriction in the Iplan
deployment. The default remains fully open.

When non-empty rules are supplied, they replace the open egress rule for every
Pod selected by the default policy. The intra-application policy only grants
ingress; it does not grant egress. A restricted policy must therefore explicitly
allow all required destinations, including:

- Cluster DNS on UDP and TCP port 53.
- PostgreSQL, MongoDB, and RabbitMQ destinations.
- Bifrost or another configured LLM provider.
- GitHub, GitLab, Bitbucket, Azure DevOps, Forgejo, or other enabled providers.
- Any other external service required by the selected Kodus features.

Without those rules, the application may start but fail to resolve services,
connect to its datastores, receive provider responses, or deliver webhooks.

## Critical NetworkPolicy Configuration Issue

The networking concept is correct, but the current values and Terraform
configuration do not consistently use Kubernetes `LabelSelector` shapes.

The template expects `ingressControllerNamespaceSelector` to be a complete
LabelSelector, for example:

```yaml
ingressControllerNamespaceSelector:
  matchLabels:
    kubernetes.io/metadata.name: tailscale
```

The Terraform configuration currently supplies a raw label map:

```hcl
ingressControllerNamespaceSelector = {
  "kubernetes.io/metadata.name" = "tailscale"
}
```

The additional source is also supplied as raw maps:

```hcl
namespaceSelector = {
  "kubernetes.io/metadata.name" = "istio-system"
}
podSelector = {
  app = "istio-ingressgateway"
}
```

The resulting shape should instead be:

```yaml
additionalIngressSources:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: istio-system
    podSelector:
      matchLabels:
        app: istio-ingressgateway
```

The primary `ingressControllerLabels` value is different: the template wraps
it in `podSelector.matchLabels`, so it should remain a raw label map.

There is a second problem with the local default:

```yaml
ingressControllerLabels:
  app.kubernetes.io/component: controller
  app.kubernetes.io/name: ingress-nginx
```

Helm merges maps. When Terraform adds `tailscale.com/managed=true`, those nginx
labels may remain in the resulting selector. That can require a Tailscale Pod
to have both nginx labels and the Tailscale label, which it does not.

The current network configuration is therefore not safe to call production
ready until the following are resolved:

- Use valid `matchLabels` structures for namespace and additional selectors.
- Avoid merging nginx defaults into a Tailscale selector.
- Add unit tests for the rendered ingress selectors.
- Render and validate the chart using the exact Terraform values.

The intended values shape is:

```yaml
networkPolicy:
  ingressControllerLabels:
    tailscale.com/managed: "true"
  ingressControllerNamespaceSelector:
    matchLabels:
      kubernetes.io/metadata.name: tailscale
  additionalIngressSources:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: istio-system
      podSelector:
        matchLabels:
          app: istio-ingressgateway
```

The current `networkpolicy_test.yaml` tests only egress. It does not catch
these ingress selector problems.

## Customization Impact Matrix

| Customization | Impact | Relevant to Iplan? | Fork justification |
|---|---|---|---|
| GitHub credentials in `secretKeyRef` | High; required for GitHub App/OAuth integration | Yes | Strong |
| Multiple NetworkPolicy ingress sources | High; required for Tailscale plus Istio | Yes | Strong, after selector fixes |
| `secretVersion` rollout checksum | Medium/high; supports external Secret rotation | Yes when rotating credentials | Strong, but Terraform must set it |
| Automatic MCP disable flag | Medium; avoids advertising a disabled MCP service | Yes | Useful |
| Migration `activeDeadlineSeconds` | Medium; prevents indefinitely running Jobs | Yes | Reasonable |
| Per-host Ingress `enabled` flags | High for the documented pilot; prevents exposing web/API hosts | No for Iplan, which disables chart Ingress | Needed only if bundled pilot remains supported |
| Read-only bundled datastores | Medium/high security hardening | No; Iplan uses external datastores | Needed only for bundled pilot |
| RabbitMQ bundled password guard | Low/medium; protects raw URI construction | No; Iplan uses an external URI | Weak |
| Configurable ExternalSecret key prefix | Low; useful for alternate secret stores | No; Iplan uses `global.existingSecret` | Weak |
| Configurable egress rules | Low currently; default remains open | No; Iplan does not configure restrictions | Future capability |
| JWT TTL changed from `365d` to `1h` | High security value | Yes, unless explicitly overridden | Values override is sufficient |
| PostgreSQL SSL default changed to disabled=false | Questionable; conflicts with bundled default | No; Terraform explicitly sets disabled=true | Should likely be reverted |
| Single base64 encoding for generated JWT values | Low; corrects representation but double encoding still retains entropy | No; Iplan supplies an existing Secret | Correctness improvement, weak fork justification |
| Migration `echo` changed to `exit 0` | None; both exit successfully | No | None |
| Comment cleanup and dead helper removal | None at runtime | No | None |

## Secret Rotation Gap

The local chart changes the Deployment secret checksum to use
`global.secretVersion` when an externally managed Secret is configured. This
is necessary because the chart cannot hash the contents of a Secret it does not
own.

However, the current Terraform Helm values do not set `global.secretVersion`.
Updating `kodus-secrets` alone therefore does not clearly guarantee a Kodus
rollout. The deployment process needs an explicit version or revision value
that changes whenever the Secret changes.

The local mechanism is valuable, but it is incomplete until the Terraform
deployment consumes it.

## Values That Should Not Require A Fork

These are deployment-specific configuration and can be supplied through a
wrapper chart, Terraform values, or a direct upstream chart installation:

- `API_JWT_EXPIRES_IN=1h`.
- PostgreSQL SSL behavior.
- External datastore hosts and Secret keys.
- Bifrost endpoint and model.
- Replica counts.
- Disabled services.
- Tailscale and Istio selector values.
- Private and public hostnames.

The fact that the local chart currently places some of these in `values.yaml`
does not mean the upstream templates need to be forked.

## Documentation Inconsistencies

The documentation should be normalized before a long-term synchronization
strategy is chosen.

- `kodus-pilot-pr-review.md` describes the bundled pilot as the main flow.
- Later sections of `kodus-deploy-plan.md` describe external CloudPirates stores and the Iplan cluster.
- `kodus_contract.md` still references Infisical and an older Kubernetes context.
- `README.md` still refers to the DeepSeek model, while the deployment plan uses `openai.gpt-5.6-luna` through Bifrost.
- The hardening checklist correctly treats bundled datastores as pilot-only and recommends external/operator-managed services for production.

The team should explicitly decide whether bundled pilot support is a permanent
supported mode or historical documentation.

## Recommendation

For the current Iplan deployment, the strongest local template requirements are:

1. GitHub credential injection through `secretKeyRef`.
2. Multiple NetworkPolicy ingress sources.
3. A reliable external Secret rotation rollout mechanism.
4. Migration Job deadline.

The first two should be proposed upstream. Until they are accepted and
published, a local fork or a post-rendering patch layer is justified.

The following should be moved to deployment-specific values or overlays:

- JWT expiration.
- SSL mode.
- Datastore modes.
- Bifrost settings.
- Replica and service enablement settings.
- Tailscale and Istio selectors.

The following should be removed from the fork unless bundled pilot support is a
firm requirement:

- Bundled datastore filesystem hardening.
- RabbitMQ bundled password guard.
- ExternalSecret prefix customization.

The top-level SSL default should likely return to the upstream bundled-safe
default and be overridden explicitly for external deployments.

## Team Decisions Needed

- Is the bundled datastore pilot a supported product path or only a temporary evaluation path?
- Should GitHub secret injection and multiple ingress sources be contributed upstream?
- Should the chart expose full Kubernetes `LabelSelector` objects or raw label maps in values?
- Should the default ingress policy be permissive, nginx-specific, or deny-until-configured?
- Who owns updating `global.secretVersion` after Secret rotation?
- Should egress restrictions be implemented now or remain an extension point?
- Should the local chart become an upstream OCI dependency after the required upstream changes are released?
