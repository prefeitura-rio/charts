{{/*
Expand the name of the chart.
*/}}
{{- define "cloudsql-proxy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cloudsql-proxy.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cloudsql-proxy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cloudsql-proxy.labels" -}}
helm.sh/chart: {{ include "cloudsql-proxy.chart" . }}
{{ include "cloudsql-proxy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cloudsql-proxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cloudsql-proxy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
Logic:
- If existingServiceAccount is set, use it
- If gcpServiceAccount is set (Workload Identity), create/use named SA
- Otherwise (SA Key auth), use "default"
*/}}
{{- define "cloudsql-proxy.serviceAccountName" -}}
{{- if .Values.serviceAccount.existingServiceAccount }}
{{- .Values.serviceAccount.existingServiceAccount }}
{{- else if .Values.serviceAccount.gcpServiceAccount }}
{{- default (include "cloudsql-proxy.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Check if we should create a ServiceAccount
Only create when using Workload Identity (gcpServiceAccount is set)
*/}}
{{- define "cloudsql-proxy.createServiceAccount" -}}
{{- if and .Values.serviceAccount.gcpServiceAccount (not .Values.serviceAccount.existingServiceAccount) }}true{{- end }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "cloudsql-proxy.secretName" -}}
{{- if .Values.secret.existingSecret }}
{{- .Values.secret.existingSecret }}
{{- else if .Values.secret.create }}
{{- include "cloudsql-proxy.fullname" . }}-credentials
{{- else }}
{{- "" }}
{{- end }}
{{- end }}

{{/*
Check if we should use ConfigMap for instance configuration
*/}}
{{- define "cloudsql-proxy.useConfigMap" -}}
{{- if .Values.instance.configMapRef.name }}true{{- else }}{{- end }}
{{- end }}

{{/*
Build the Cloud SQL instance connection string (inline mode)
*/}}
{{- define "cloudsql-proxy.instanceConnectionName" -}}
{{- printf "%s:%s:%s" .Values.instance.projectId .Values.instance.region .Values.instance.name }}
{{- end }}

{{/*
Build the Cloud SQL instance connection string (ConfigMap mode with env vars)
*/}}
{{- define "cloudsql-proxy.instanceConnectionNameEnv" -}}
{{- $keys := .Values.instance.configMapRef.keys }}
{{- printf "$(%s):$(%s):$(%s)" $keys.projectId $keys.region $keys.name }}
{{- end }}

{{/*
Build proxy arguments
*/}}
{{- define "cloudsql-proxy.args" -}}
- "--port={{ .Values.proxy.port }}"
- "--address=0.0.0.0"
{{- if .Values.proxy.structuredLogs }}
- "--structured-logs"
{{- end }}
{{- if .Values.proxy.lazyRefresh }}
- "--lazy-refresh"
{{- end }}
{{- if .Values.proxy.maxConnections }}
- "--max-connections={{ .Values.proxy.maxConnections }}"
{{- end }}
{{- if .Values.proxy.autoIamAuthn }}
- "--auto-iam-authn"
{{- end }}
{{- if .Values.proxy.privateIp }}
- "--private-ip"
{{- end }}
{{- if and .Values.proxy.healthCheckPort (gt (int .Values.proxy.healthCheckPort) 0) }}
- "--health-check"
- "--http-address=0.0.0.0"
- "--http-port={{ .Values.proxy.healthCheckPort }}"
{{- end }}
{{- $secretName := include "cloudsql-proxy.secretName" . }}
{{- if $secretName }}
- "--credentials-file=/var/secrets/google/{{ .Values.secret.key }}"
{{- end }}
{{- range .Values.proxy.extraArgs }}
- {{ . | quote }}
{{- end }}
{{- if include "cloudsql-proxy.useConfigMap" . }}
- "{{ include "cloudsql-proxy.instanceConnectionNameEnv" . }}"
{{- else }}
- "{{ include "cloudsql-proxy.instanceConnectionName" . }}"
{{- end }}
{{- end }}

{{/*
Get service port (defaults to proxy.port)
*/}}
{{- define "cloudsql-proxy.servicePort" -}}
{{- default .Values.proxy.port .Values.service.port }}
{{- end }}
