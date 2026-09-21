{{/*
Expand the name of the chart.
*/}}
{{- define "base-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
By default, uses the release name to avoid redundant "base-chart" suffix.
*/}}
{{- define "base-chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "base-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "base-chart.labels" -}}
helm.sh/chart: {{ include "base-chart.chart" . }}
{{ include "base-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "base-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "base-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Resolve the full image reference (repository:tag)
*/}}
{{- define "base-chart.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default "latest") }}
{{- end }}

{{/*
Resolve imagePullSecrets - falls back to ghcr-credentials if none provided
*/}}
{{- define "base-chart.imagePullSecrets" -}}
{{- if .Values.imagePullSecrets }}
{{- toYaml .Values.imagePullSecrets }}
{{- else }}
- name: ghcr-credentials
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "base-chart.valkeyHost" -}}
{{- if .Values.valkey.sentinel.enabled -}}
{{- printf "%s-valkey-sentinel" .Release.Name -}}
{{- else -}}
{{- printf "%s-valkey" .Release.Name -}}
{{- end -}}
{{- end }}

{{- define "base-chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "base-chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Renders a single NetworkPolicyPeer as a YAML list item ("- ...") from the simplified
{namespace, workload, podSelector, namespaceSelector, ipBlock} shape used by
networkPolicy.ingress.from / networkPolicy.egress.to.
  - namespace only          -> qualquer pod do namespace
  - namespace + workload    -> só esse workload (app.kubernetes.io/name) dentro do namespace
  - namespace + podSelector -> seletor de pod customizado dentro do namespace
  - namespaceSelector (raw) -> seletor de namespace bruto do Kubernetes
  - ipBlock                 -> origem/destino por CIDR
*/}}
{{- define "base-chart.networkPolicyPeer" -}}
{{- if .namespace -}}
- namespaceSelector:
    matchLabels:
      kubernetes.io/metadata.name: {{ .namespace }}
  {{- if .workload }}
  podSelector:
    matchLabels:
      app.kubernetes.io/name: {{ .workload }}
  {{- else if .podSelector }}
  podSelector:
    {{- toYaml .podSelector | nindent 4 }}
  {{- end }}
{{- else if .namespaceSelector -}}
- namespaceSelector:
    {{- toYaml .namespaceSelector | nindent 4 }}
  {{- with .podSelector }}
  podSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- else if .ipBlock -}}
- ipBlock:
    {{- toYaml .ipBlock | nindent 4 }}
{{- end }}
{{- end }}

