{{/*
  prefect-server.authproxy-hostname:
    Determine the DNS name that the authproxy service will be hosted at.
    K8s services are discoverable at: <service-name>-<namespace>
*/}}
{{- define "prefect-server.authproxy-hostname" -}}
{{- $name := include "prefect-server.nameField" (merge (dict "component" "authproxy") .) -}}
{{ printf "%s.%s" $name .Release.Namespace }}
{{- end -}}


{{/*
  prefect-server.authproxy-api-url:
    Determine the url for the authproxy api
*/}}
{{- define "prefect-server.authproxy-api-url" -}}
{{- $host := include "prefect-server.authproxy-hostname" . -}}
{{- $port := (.Values.authproxy.service.port | default 80) -}}
{{ printf "http://%s:%v/graphql" $host $port }}
{{- end -}}

