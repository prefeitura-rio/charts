{{/*
Expand the name of the chart.
*/}}
{{- define "midpoint.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "midpoint.fullname" -}}
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
{{- define "midpoint.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "midpoint.labels" -}}
helm.sh/chart: {{ include "midpoint.chart" . }}
{{ include "midpoint.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "midpoint.selectorLabels" -}}
app.kubernetes.io/name: {{ include "midpoint.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Return the MidPoint image reference. Digest takes precedence over tag.
*/}}
{{- define "midpoint.image" -}}
{{- if .Values.image.digest }}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest }}
{{- else }}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "midpoint.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "midpoint.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the secret holding the repository (database) password
*/}}
{{- define "midpoint.database.secretName" -}}
{{- if .Values.database.existingSecret }}
{{- .Values.database.existingSecret }}
{{- else }}
{{- include "midpoint.fullname" . }}-db
{{- end }}
{{- end }}

{{/*
Key within the database secret
*/}}
{{- define "midpoint.database.secretKey" -}}
{{- if .Values.database.existingSecret }}
{{- .Values.database.existingSecretKey }}
{{- else }}
{{- "password" }}
{{- end }}
{{- end }}

{{/*
Name of the secret holding the administrator bootstrap password
*/}}
{{- define "midpoint.admin.secretName" -}}
{{- if .Values.admin.existingSecret }}
{{- .Values.admin.existingSecret }}
{{- else }}
{{- include "midpoint.fullname" . }}-admin
{{- end }}
{{- end }}

{{/*
Key within the administrator secret
*/}}
{{- define "midpoint.admin.secretKey" -}}
{{- if .Values.admin.existingSecret }}
{{- .Values.admin.existingSecretKey }}
{{- else }}
{{- "password" }}
{{- end }}
{{- end }}

{{/*
Name of the ConfigMap holding schema extension files
*/}}
{{- define "midpoint.schemaExtension.configMapName" -}}
{{- if .Values.schemaExtension.existingConfigMap }}
{{- .Values.schemaExtension.existingConfigMap }}
{{- else }}
{{- include "midpoint.fullname" . }}-schema-extension
{{- end }}
{{- end }}

{{/*
JDBC URL for the MidPoint repository
*/}}
{{- define "midpoint.jdbcUrl" -}}
{{- printf "jdbc:postgresql://%s:%s/%s" .Values.database.host (.Values.database.port | toString) .Values.database.name }}
{{- end }}
