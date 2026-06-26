{{/*
Expand the chart name.
*/}}
{{- define "sequin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name. Truncated at 63 chars (DNS spec).
*/}}
{{- define "sequin.fullname" -}}
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
Chart name and version label value.
*/}}
{{- define "sequin.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels. Accepts dict with "customLabels" (map or YAML string) and "context" (root scope).
Mirrors common.labels.standard: customLabels are merged first (higher priority); standard labels
fill in any missing keys. Extra keys from customLabels are preserved.
*/}}
{{- define "sequin.labels" -}}
{{- $ctx := .context -}}
{{- $default := dict
    "app.kubernetes.io/name"       (include "sequin.fullname" $ctx)
    "helm.sh/chart"                (include "sequin.chart" $ctx)
    "app.kubernetes.io/instance"   $ctx.Release.Name
    "app.kubernetes.io/managed-by" $ctx.Release.Service -}}
{{- if $ctx.Chart.AppVersion -}}
{{- $_ := set $default "app.kubernetes.io/version" ($ctx.Chart.AppVersion | replace "+" "_") -}}
{{- end -}}
{{- $customMap := dict -}}
{{- with .customLabels -}}
{{- if typeIs "string" . -}}
{{- $customMap = (. | fromYaml) -}}
{{- else -}}
{{- $customMap = . -}}
{{- end -}}
{{- end -}}
{{- merge $customMap $default | toYaml -}}
{{- end }}

{{/*
Selector labels. Accepts dict with "customLabels" (map or YAML string) and "context" (root scope).
Mirrors common.labels.matchLabels: only picks app.kubernetes.io/name and app.kubernetes.io/instance
from customLabels (allowing user override of those two keys), then merges with context defaults.
No arbitrary custom labels are added to matchLabels (immutable field — would break rolling updates).
*/}}
{{- define "sequin.selectorLabels" -}}
{{- $ctx := .context -}}
{{- $default := dict
    "app.kubernetes.io/name"     (include "sequin.fullname" $ctx)
    "app.kubernetes.io/instance" $ctx.Release.Name -}}
{{- $customMap := dict -}}
{{- with .customLabels -}}
{{- if typeIs "string" . -}}
{{- $customMap = (. | fromYaml) -}}
{{- else -}}
{{- $customMap = . -}}
{{- end -}}
{{- end -}}
{{- $picked := pick $customMap "app.kubernetes.io/name" "app.kubernetes.io/instance" -}}
{{- merge $picked $default | toYaml -}}
{{- end }}

{{/*
Render a value as a template. Accepts dict with "value" and "context".
Replaces common.tplvalues.render.
*/}}
{{- define "sequin.tplrender" -}}
{{- $value := .value -}}
{{- if typeIs "string" $value }}
{{- tpl $value .context }}
{{- else }}
{{- tpl (toYaml $value) .context }}
{{- end }}
{{- end }}

{{/*
Merge a list of values into a single map and render as YAML.
Accepts dict with "values" (list of maps) and "context".
Replaces common.tplvalues.merge.
*/}}
{{- define "sequin.mergeValues" -}}
{{- $merged := dict -}}
{{- range .values -}}
{{- if . -}}
{{- $merged = merge $merged . -}}
{{- end -}}
{{- end -}}
{{- toYaml $merged -}}
{{- end }}

{{/*
Render a securityContext, stripping the "enabled" field (Helm values convention, not K8s API).
Accepts dict with "secContext" (map) and "context".
Replaces common.compatibility.renderSecurityContext (Openshift shim removed — plain K8s only).
*/}}
{{- define "sequin.renderSecurityContext" -}}
{{- omit .secContext "enabled" | toYaml -}}
{{- end }}

{{/*
Pod affinity/anti-affinity preset block.
Accepts dict with "type" ("soft"|"hard"|""), "customLabels", "context".
Replaces common.affinities.pods.
*/}}
{{- define "sequin.affinities.pods" -}}
{{- $type := default "" .type -}}
{{- if eq $type "soft" -}}
preferredDuringSchedulingIgnoredDuringExecution:
  - podAffinityTerm:
      labelSelector:
        matchLabels: {{- include "sequin.selectorLabels" (dict "customLabels" .customLabels "context" .context) | nindent 10 }}
      topologyKey: kubernetes.io/hostname
    weight: 1
{{- else if eq $type "hard" -}}
requiredDuringSchedulingIgnoredDuringExecution:
  - labelSelector:
      matchLabels: {{- include "sequin.selectorLabels" (dict "customLabels" .customLabels "context" .context) | nindent 8 }}
    topologyKey: kubernetes.io/hostname
{{- end -}}
{{- end }}

{{/*
Node affinity preset block.
Accepts dict with "type" ("soft"|"hard"|""), "key", "values".
Replaces common.affinities.nodes.
*/}}
{{- define "sequin.affinities.nodes" -}}
{{- $type := default "" .type -}}
{{- if and $type .key .values -}}
{{- if eq $type "soft" -}}
preferredDuringSchedulingIgnoredDuringExecution:
  - preference:
      matchExpressions:
        - key: {{ .key }}
          operator: In
          values: {{- toYaml .values | nindent 12 }}
    weight: 1
{{- else if eq $type "hard" -}}
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
    - matchExpressions:
        - key: {{ .key }}
          operator: In
          values: {{- toYaml .values | nindent 12 }}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Return resource requests/limits for a given preset tier.
Local copy of bitnami/common.resources.preset — removes the bitnami/common dependency
while preserving identical behavior. Default tier in use: "small".
*/}}
{{- define "sequin.resources.preset" -}}
{{- $presets := dict
  "nano"    (dict "requests" (dict "cpu" "100m" "memory" "128Mi"  "ephemeral-storage" "50Mi")
                  "limits"   (dict "cpu" "150m" "memory" "192Mi"  "ephemeral-storage" "2Gi"))
  "micro"   (dict "requests" (dict "cpu" "250m" "memory" "256Mi"  "ephemeral-storage" "50Mi")
                  "limits"   (dict "cpu" "375m" "memory" "384Mi"  "ephemeral-storage" "2Gi"))
  "small"   (dict "requests" (dict "cpu" "500m" "memory" "512Mi"  "ephemeral-storage" "50Mi")
                  "limits"   (dict "cpu" "750m" "memory" "768Mi"  "ephemeral-storage" "2Gi"))
  "medium"  (dict "requests" (dict "cpu" "500m" "memory" "1024Mi" "ephemeral-storage" "50Mi")
                  "limits"   (dict "cpu" "750m" "memory" "1536Mi" "ephemeral-storage" "2Gi"))
  "large"   (dict "requests" (dict "cpu" "1.0"  "memory" "2048Mi" "ephemeral-storage" "50Mi")
                  "limits"   (dict "cpu" "1.5"  "memory" "3072Mi" "ephemeral-storage" "2Gi"))
  "xlarge"  (dict "requests" (dict "cpu" "1.0"  "memory" "3072Mi" "ephemeral-storage" "50Mi")
                  "limits"   (dict "cpu" "3.0"  "memory" "6144Mi" "ephemeral-storage" "2Gi"))
  "2xlarge" (dict "requests" (dict "cpu" "1.0"  "memory" "3072Mi" "ephemeral-storage" "50Mi")
                  "limits"   (dict "cpu" "6.0"  "memory" "12288Mi" "ephemeral-storage" "2Gi"))
}}
{{- if hasKey $presets .type -}}
{{- index $presets .type | toYaml -}}
{{- else -}}
{{- printf "ERROR: Preset key '%s' invalid. Allowed values are %s" .type (join "," (keys $presets)) | fail -}}
{{- end -}}
{{- end }}

{{/*
Return the proper Sequin image name (registry/repository:tag or repository:tag).
Replaces common.images.image.
*/}}
{{- define "sequin.image" -}}
{{- $registry := coalesce .Values.global.imageRegistry .Values.image.registry "" -}}
{{- $repository := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- $digest := .Values.image.digest | default "" -}}
{{- if $digest -}}
{{- if $registry -}}
{{- printf "%s/%s@%s" $registry $repository $digest -}}
{{- else -}}
{{- printf "%s@%s" $repository $digest -}}
{{- end -}}
{{- else -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- else -}}
{{- printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Return imagePullSecrets block (merges global and local).
Replaces common.images.pullSecrets.
*/}}
{{- define "sequin.imagePullSecrets" -}}
{{- $pullSecrets := concat (.Values.global.imagePullSecrets | default list) (.Values.image.pullSecrets | default list) -}}
{{- if $pullSecrets }}
imagePullSecrets:
{{- range $pullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Get the Sequin configuration ConfigMap name.
*/}}
{{- define "sequin.configmapName" -}}
{{- if .Values.existingConfigmap -}}
    {{- tpl .Values.existingConfigmap . -}}
{{- else }}
    {{- include "sequin.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use.
*/}}
{{- define "sequin.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "sequin.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Sequin credential secret name.
*/}}
{{- define "sequin.secretName" -}}
{{- coalesce .Values.existingSecret (include "sequin.fullname" .) -}}
{{- end -}}

{{/*
Create a default fully qualified app name for PostgreSQL.
Replaces common.names.dependency.fullname for the postgresql sub-chart.
PostgreSQL is always disabled in our config (externalDatabase path is used instead).
*/}}
{{- define "sequin.postgresql.fullname" -}}
{{- if .Values.postgresql.fullnameOverride -}}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-postgresql" (include "sequin.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Return the Database Hostname.
*/}}
{{- define "sequin.database.host" -}}
{{- ternary (include "sequin.postgresql.fullname" .) .Values.externalDatabase.host .Values.postgresql.enabled -}}
{{- end -}}

{{/*
Return the Database Port.
*/}}
{{- define "sequin.database.port" -}}
{{- ternary "5432" .Values.externalDatabase.port .Values.postgresql.enabled -}}
{{- end -}}

{{/*
Return the Database Name.
*/}}
{{- define "sequin.database.name" -}}
{{- if .Values.postgresql.enabled }}
    {{- if .Values.global.postgresql }}
        {{- if .Values.global.postgresql.auth }}
            {{- coalesce .Values.global.postgresql.auth.database .Values.postgresql.auth.database -}}
        {{- else -}}
            {{- .Values.postgresql.auth.database -}}
        {{- end -}}
    {{- else -}}
        {{- .Values.postgresql.auth.database -}}
    {{- end -}}
{{- else -}}
    {{- .Values.externalDatabase.database -}}
{{- end -}}
{{- end -}}

{{/*
Return the Database User.
*/}}
{{- define "sequin.database.username" -}}
{{- if .Values.postgresql.enabled }}
    {{- if .Values.global.postgresql }}
        {{- if .Values.global.postgresql.auth }}
            {{- coalesce .Values.global.postgresql.auth.username .Values.postgresql.auth.username -}}
        {{- else -}}
            {{- .Values.postgresql.auth.username -}}
        {{- end -}}
    {{- else -}}
        {{- .Values.postgresql.auth.username -}}
    {{- end -}}
{{- else -}}
    {{- .Values.externalDatabase.user -}}
{{- end -}}
{{- end -}}

{{/*
Return the Database Secret Name.
*/}}
{{- define "sequin.database.secretName" -}}
{{- if .Values.postgresql.enabled }}
    {{- if .Values.global.postgresql }}
        {{- if .Values.global.postgresql.auth }}
            {{- if .Values.global.postgresql.auth.existingSecret }}
                {{- tpl .Values.global.postgresql.auth.existingSecret $ -}}
            {{- else -}}
                {{- default (include "sequin.postgresql.fullname" .) (tpl .Values.postgresql.auth.existingSecret $) -}}
            {{- end -}}
        {{- else -}}
            {{- default (include "sequin.postgresql.fullname" .) (tpl .Values.postgresql.auth.existingSecret $) -}}
        {{- end -}}
    {{- else -}}
        {{- default (include "sequin.postgresql.fullname" .) (tpl .Values.postgresql.auth.existingSecret $) -}}
    {{- end -}}
{{- else -}}
    {{- default (printf "%s-externaldb" (include "sequin.fullname" .)) (tpl .Values.externalDatabase.existingSecret $) -}}
{{- end -}}
{{- end -}}

{{/*
Get the Redis&reg; fullname.
Replaces common.names.dependency.fullname for the redis sub-chart.
Redis is always disabled in our config (externalRedis path is used instead).
*/}}
{{- define "sequin.redis.fullname" -}}
{{- if .Values.redis.fullnameOverride -}}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-redis" (include "sequin.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified redis name.
*/}}
{{- define "sequin.redis.host" -}}
{{- if .Values.redis.enabled -}}
    {{- printf "%s-master" (include "sequin.redis.fullname" .) -}}
{{- else -}}
    {{- printf "%s" (tpl .Values.externalRedis.host $) -}}
{{- end -}}
{{- end -}}

{{/*
Get the Redis&reg; port.
*/}}
{{- define "sequin.redis.port" -}}
{{- if .Values.redis.enabled -}}
    {{- print .Values.redis.master.service.ports.redis -}}
{{- else -}}
    {{- print .Values.externalRedis.port  -}}
{{- end -}}
{{- end -}}

{{/*
Get the Redis&reg; credentials secret.
*/}}
{{- define "sequin.redis.secretName" -}}
{{- if .Values.redis.enabled -}}
    {{- if .Values.redis.auth.existingSecret -}}
        {{- print (tpl .Values.redis.auth.existingSecret .) -}}
    {{- else -}}
        {{- printf "%s-svcbind" (include "sequin.redis.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalRedis.existingSecret -}}
    {{- print (tpl .Values.externalRedis.existingSecret .) -}}
{{- else -}}
    {{- printf "%s-externalredis" (include "sequin.fullname" .) -}}
{{- end -}}
{{- end -}}
