{{/*
  prefect-server.auth-proxy-hostname:
    Determine the DNS name that the auth-proxy service will be hosted at.
    K8s services are discoverable at: <service-name>-<namespace>
*/}}
{{- define "prefect-server.auth-proxy-hostname" -}}
{{- $name := include "prefect-server.nameField" (merge (dict "component" "auth-proxy") .) -}}
{{ printf "%s.%s" $name .Release.Namespace }}
{{- end -}}


{{/*
  prefect-server.auth-proxy-api-url:
    Determine the url for the auth-proxy api
*/}}
{{- define "prefect-server.auth-proxy-api-url" -}}
{{- $host := include "prefect-server.auth-proxy-hostname" . -}}
{{- $port := (.Values.auth-proxy.service.port | default 80) -}}
{{ printf "http://%s:%v/graphql" $host $port }}
{{- end -}}

