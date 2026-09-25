# Kodus Fork Justification

Date: 2026-09-25

This document records the three local customizations that currently justify
maintaining a modified Kodus chart instead of consuming the upstream OCI chart
unchanged.

The current Iplan deployment uses:

- A Terraform/SOPS-managed Secret named `kodus-secrets`.
- Private web and API access through Tailscale.
- Public webhook access through an Istio ingress gateway.
- NetworkPolicy enabled.
- External PostgreSQL, MongoDB, and RabbitMQ.

## 1. GitHub Credential Injection

### Problem in the upstream chart

The application Deployments load configuration from a ConfigMap and load
Secrets through the `kodus-common.appSecretsEnv` helper. The upstream helper
does not include these keys:

```text
API_GITHUB_CLIENT_SECRET
API_GITHUB_PRIVATE_KEY
WEB_OAUTH_GITHUB_CLIENT_SECRET
```

The upstream chart does not use `envFrom.secretRef` for the complete
`global.existingSecret`. Therefore, placing these values in `kodus-secrets` does
not inject them into the application containers.

Putting them in `global.config` would expose them through a ConfigMap and is not
acceptable, especially for the private key.

### Local solution

The local `kodus-common/templates/_env.tpl` adds the three keys to the optional
Secret references used by the application Pods:

```yaml
- name: API_GITHUB_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: <existing-secret>
      key: API_GITHUB_CLIENT_SECRET
      optional: true
```

The same pattern is applied to the private key and OAuth client secret.

### Assessment

This is a **required functional change** for the current GitHub App and OAuth
deployment model. It cannot be implemented with values alone. It requires one
of:

- A local chart fork.
- An upstream chart change.
- A post-renderer or equivalent manifest patch.

This change should be proposed upstream.

## 2. Multiple NetworkPolicy Ingress Sources

### Required traffic

The deployment has two independent ingress paths:

```text
Tailscale proxy Pod in namespace tailscale
  -> kodus-web or kodus-api Service
  -> Kodus web or API Pod

Istio ingress gateway Pod in namespace istio-system
  -> kodus-webhooks Service
  -> Kodus webhooks Pod
```

The Tailscale operator's generated proxy Pods use:

```text
tailscale.com/managed=true
```

The Istio gateway uses:

```text
app=istio-ingressgateway
```

The upstream chart supports only one ingress-controller source. Adding the
Istio source would otherwise require disabling the policy or creating a second
NetworkPolicy outside the chart.

### Local solution

The local chart adds the `additionalIngressSources` value and renders each
additional source as another Kubernetes NetworkPolicy peer while keeping the
primary controller source available. The primary controller selector already
exists in the upstream chart.

This is a **required functional change** for the Tailscale-plus-Istio topology.
It cannot be represented solely through values against the upstream template.

### Selector-shape issue to resolve

The concept is required, but the current Terraform values do not match the
Kubernetes `LabelSelector` structure expected by the template.

The namespace selector must be rendered as:

```yaml
namespaceSelector:
  matchLabels:
    kubernetes.io/metadata.name: tailscale
```

An additional source must be rendered as:

```yaml
additionalIngressSources:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: istio-system
    podSelector:
      matchLabels:
        app: istio-ingressgateway
```

The current Terraform configuration supplies raw maps instead of complete
`LabelSelector` objects. The local default also contains nginx labels, which
can merge with Tailscale labels through Helm's map-merging behavior.

Before deployment, these issues must be fixed by either:

- Supplying the correct selector shapes and avoiding nginx defaults.
- Changing the chart values contract and template to consistently accept raw label maps.

The NetworkPolicy test suite must also assert the rendered ingress selectors,
not only egress behavior.

## 3. External Secret Rotation Rollout

### Problem

When `global.existingSecret` or ExternalSecrets are used, the chart does not
own the Secret contents. Hashing `templates/secrets.yaml` therefore does not
change when the external Secret rotates.

Without a changing Pod annotation, application Pods can continue running with
old environment variables after the Kubernetes Secret is updated.

### Local solution

The local chart adds:

```yaml
global:
  secretVersion: ""
```

When an external Secret is configured, the Deployment checksum uses this value:

```text
checksum/secrets = sha256(global.secretVersion)
```

Changing `global.secretVersion` causes a rolling restart and makes the Pods read
the new Secret values.

### Current integration gap

The Terraform deployment currently configures `global.existingSecret` but does
not set `global.secretVersion`. The mechanism exists in the chart, but Secret
rotation still requires an explicit deployment revision or another rollout
trigger.

Terraform must derive or maintain a non-secret revision value that changes when
the managed Secret changes. The secret contents themselves must not be exposed
in Helm values or annotations.

### Assessment

This is a **meaningful operational customization** for externally managed
credentials. It cannot be solved with ordinary chart values against the
upstream template unless the upstream chart already provides an equivalent
checksum mechanism.

This change should also be proposed upstream.

## Decision

These are the three local customizations that justify the fork today:

1. GitHub credential injection through Secret references.
2. Multiple NetworkPolicy ingress sources for Tailscale and Istio.
3. Explicit rollout signaling for externally managed Secret rotation.

Other local differences should not be considered fork justifications by
themselves. They should be evaluated separately as deployment values, pilot
hardening, upstream contributions, or removable drift.

The preferred long-term path is:

1. Correct and test the local implementations.
2. Submit the three generic improvements upstream.
3. Move to the upstream OCI chart once equivalent upstream functionality is released.
