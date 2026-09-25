{{- define "kodus.fullname" -}}
{{ include "kodus-common.fullname" . }}
{{- end }}

{{- define "kodus.labels" -}}
{{ include "kodus-common.labels" . }}
{{- end }}

{{- define "kodus.serviceAccountName" -}}
{{ include "kodus-common.serviceAccountName" . }}
{{- end }}

{{- define "kodus.webhooksBaseUrl" -}}
{{- $host := "" -}}
{{- $scheme := "https" -}}
{{- if eq .Values.platform "openshift" -}}
{{- if .Values.route.enabled -}}{{- with .Values.route.hosts.webhooks }}{{- $host = .host | default "" -}}{{- end -}}{{- end -}}
{{- else -}}
{{- if .Values.ingress.enabled -}}{{- with .Values.ingress.hosts.webhooks }}{{- $host = .host | default "" -}}{{- end -}}{{- end -}}
{{- if not .Values.ingress.tls.enabled -}}{{- $scheme = "http" -}}{{- end -}}
{{- end -}}
{{- if and $host (not (contains "example.com" $host)) -}}{{ printf "%s://%s" $scheme $host }}{{- end -}}
{{- end -}}

{{- define "kodus.webBaseUrl" -}}
{{- $url := (.Values.global.config.NEXTAUTH_URL | default "") -}}
{{- if and $url (not (contains "example.com" $url)) -}}
{{ trimSuffix "/" $url }}
{{- else -}}
{{- $host := "" -}}
{{- $scheme := "https" -}}
{{- if eq .Values.platform "openshift" -}}
{{- if .Values.route.enabled -}}{{- with .Values.route.hosts.web }}{{- $host = .host | default "" -}}{{- end -}}{{- end -}}
{{- else -}}
{{- if .Values.ingress.enabled -}}{{- with .Values.ingress.hosts.web }}{{- $host = .host | default "" -}}{{- end -}}{{- end -}}
{{- if not .Values.ingress.tls.enabled -}}{{- $scheme = "http" -}}{{- end -}}
{{- end -}}
{{- if and $host (not (contains "example.com" $host)) -}}{{ printf "%s://%s" $scheme $host }}{{- end -}}
{{- end -}}
{{- end -}}

{{- define "kodus.webhookProviders" -}}
API_GITHUB_CODE_MANAGEMENT_WEBHOOK: github
API_GITLAB_CODE_MANAGEMENT_WEBHOOK: gitlab
GLOBAL_BITBUCKET_CODE_MANAGEMENT_WEBHOOK: bitbucket
GLOBAL_AZURE_REPOS_CODE_MANAGEMENT_WEBHOOK: azure-repos
API_FORGEJO_CODE_MANAGEMENT_WEBHOOK: forgejo
{{- end }}

{{- define "kodus.secretKeysHex" -}}
- API_CRYPTO_KEY
- CODE_MANAGEMENT_SECRET
- API_MCP_MANAGER_ENCRYPTION_SECRET
{{- end }}
{{- define "kodus.secretKeysB64" -}}
- API_JWT_SECRET
- API_JWT_REFRESH_SECRET
- WEB_NEXTAUTH_SECRET
- API_MCP_MANAGER_JWT_SECRET
- CODE_MANAGEMENT_WEBHOOK_TOKEN
{{- end }}

{{- define "kodus.validateServiceNames" -}}
{{- $reserved := list "postgres" "mongodb" "rabbitmq" }}
{{- range $name, $svc := .Values.services }}
{{- if has $name $reserved }}
{{- fail (printf "ERROR: services.%s is a reserved name. The bundled %s StatefulSet labels its pods app.kubernetes.io/name=%s, so this service's selector would match the datastore pods instead of its own. Rename the service (e.g. %s-api)." $name $name $name $name) }}
{{- end }}
{{- end }}
{{- end }}
