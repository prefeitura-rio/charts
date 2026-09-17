{{/* Expand the chart name. */}}
{{- define "cloudsql-proxy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Create the legacy release name. */}}
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

{{/* Derive a DNS-safe instance name. */}}
{{- define "cloudsql-proxy.instanceName" -}}
{{- $raw := printf "%s-%s" .instance.project .instance.instance | lower | replace "." "-" | replace "_" "-" | trimAll "-" }}
{{- $raw | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels for an instance. */}}
{{- define "cloudsql-proxy.instanceLabels" -}}
app.kubernetes.io/name: {{ include "cloudsql-proxy.name" .root }}
app.kubernetes.io/instance: {{ include "cloudsql-proxy.instanceName" . }}
{{- end }}

{{/* Chart labels for the shared resources. */}}
{{- define "cloudsql-proxy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "cloudsql-proxy.labels" -}}
helm.sh/chart: {{ include "cloudsql-proxy.chart" . }}
app.kubernetes.io/name: {{ include "cloudsql-proxy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "cloudsql-proxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cloudsql-proxy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Shared ServiceAccount and Secret helpers. */}}
{{- define "cloudsql-proxy.serviceAccountName" -}}
{{- if .Values.serviceAccount.existingServiceAccount }}
{{- .Values.serviceAccount.existingServiceAccount }}
{{- else if .Values.serviceAccount.gcpServiceAccount }}
{{- default (include "cloudsql-proxy.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
{{- define "cloudsql-proxy.createServiceAccount" -}}
{{- if and .Values.serviceAccount.gcpServiceAccount (not .Values.serviceAccount.existingServiceAccount) }}true{{- end }}
{{- end }}
{{- define "cloudsql-proxy.secretName" -}}
{{- if .Values.secret.existingSecret }}
{{- .Values.secret.existingSecret }}
{{- else if .Values.secret.create }}
{{- include "cloudsql-proxy.fullname" . }}-credentials
{{- else }}
{{- "" }}
{{- end }}
{{- end }}

{{/* Instance accessors with legacy fallbacks. */}}
{{- define "cloudsql-proxy.instanceProject" -}}{{- .instance.project -}}{{- end }}
{{- define "cloudsql-proxy.instanceRegion" -}}{{- .instance.region -}}{{- end }}
{{- define "cloudsql-proxy.instanceDatabase" -}}{{- .instance.instance -}}{{- end }}
{{- define "cloudsql-proxy.instancePort" -}}{{- required "instances[].port is required" .instance.port -}}{{- end }}
{{- define "cloudsql-proxy.instanceListenPort" -}}{{- required "instances[].listenPort is required" .instance.listenPort -}}{{- end }}
{{- define "cloudsql-proxy.validateInstances" -}}
{{- $ports := dict }}
{{- range .Values.instances }}
  {{- $port := int (required "instances[].listenPort is required" .listenPort) }}
  {{- if or (lt $port 1024) (gt $port 65535) }}{{ fail (printf "listenPort %d must be between 1024 and 65535" $port) }}{{ end }}
  {{- $key := printf "%d" $port }}
  {{- if hasKey $ports $key }}{{ fail (printf "duplicate listenPort %d" $port) }}{{ end }}
  {{- $_ := set $ports $key true }}
{{- end }}
{{- end }}
{{- define "cloudsql-proxy.instanceHealthPort" -}}{{- default 0 .instance.healthCheckPort -}}{{- end }}
{{- define "cloudsql-proxy.instancePrivateIp" -}}{{- if hasKey .instance "privateIp" }}{{ .instance.privateIp }}{{ else }}{{ .root.Values.proxy.privateIp }}{{ end }}{{- end }}
{{- define "cloudsql-proxy.instanceAutoIamAuthn" -}}{{- if hasKey .instance "autoIamAuthn" }}{{ .instance.autoIamAuthn }}{{ else }}{{ .root.Values.proxy.autoIamAuthn }}{{ end }}{{- end }}
{{- define "cloudsql-proxy.instanceConfigMapName" -}}{{- if hasKey .instance "configMapRef" }}{{- .instance.configMapRef.name }}{{- end }}{{- end }}
{{- define "cloudsql-proxy.instanceConfigMapKeys" -}}{{- if hasKey .instance "configMapRef" }}{{- .instance.configMapRef.keys | toYaml }}{{- end }}{{- end }}
{{- define "cloudsql-proxy.useConfigMap" -}}{{- if include "cloudsql-proxy.instanceConfigMapName" . }}true{{- end }}{{- end }}

{{/* Build proxy arguments for one instance. */}}
{{- define "cloudsql-proxy.instanceArgs" -}}
- "--port={{ include "cloudsql-proxy.instancePort" . }}"
- "--address=0.0.0.0"
{{- if .root.Values.proxy.structuredLogs }}
- "--structured-logs"
{{- end }}
{{- if .root.Values.proxy.lazyRefresh }}
- "--lazy-refresh"
{{- end }}
{{- if .root.Values.proxy.maxConnections }}
- "--max-connections={{ .root.Values.proxy.maxConnections }}"
{{- end }}
{{- if eq (include "cloudsql-proxy.instanceAutoIamAuthn" .) "true" }}
- "--auto-iam-authn"
{{- end }}
{{- if eq (include "cloudsql-proxy.instancePrivateIp" .) "true" }}
- "--private-ip"
{{- end }}
{{- $health := include "cloudsql-proxy.instanceHealthPort" . | int }}
{{- if gt $health 0 }}
- "--health-check"
- "--http-address=0.0.0.0"
- "--http-port={{ $health }}"
{{- end }}
{{- $secretName := include "cloudsql-proxy.secretName" .root }}
{{- if $secretName }}
- "--credentials-file=/var/secrets/google/{{ .root.Values.secret.key }}"
{{- end }}
{{- range .root.Values.proxy.extraArgs }}
- {{ . | quote }}
{{- end }}
{{- if include "cloudsql-proxy.useConfigMap" . }}
{{- $keys := include "cloudsql-proxy.instanceConfigMapKeys" . | fromYaml }}
- "$({{ $keys.projectId }}):$({{ $keys.region }}):$({{ $keys.name }})"
{{- else }}
- "{{ include "cloudsql-proxy.instanceProject" . }}:{{ include "cloudsql-proxy.instanceRegion" . }}:{{ include "cloudsql-proxy.instanceDatabase" . }}"
{{- end }}
{{- end }}

{{- define "cloudsql-proxy.servicePort" -}}{{- default .Values.proxy.port .Values.service.port -}}{{- end }}
