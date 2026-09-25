{{- define "kodus-common.probes" -}}
{{- if eq (default "http" .svc.probes.type) "exec" }}
startupProbe:
  exec:
    command: {{ .svc.probes.command | toJson }}
  periodSeconds: 5
  timeoutSeconds: 5
  failureThreshold: 30
livenessProbe:
  exec:
    command: {{ .svc.probes.command | toJson }}
  periodSeconds: 15
  timeoutSeconds: 5
  failureThreshold: 3
readinessProbe:
  exec:
    command: {{ .svc.probes.command | toJson }}
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
{{- else }}
startupProbe:
  httpGet:
    path: {{ .svc.probes.path }}
    port: {{ .svc.probes.port | default "http" }}
  periodSeconds: 5
  timeoutSeconds: 8
  failureThreshold: 30
livenessProbe:
  httpGet:
    path: {{ .svc.probes.path }}
    port: {{ .svc.probes.port | default "http" }}
  periodSeconds: 15
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: {{ .svc.probes.readinessPath | default .svc.probes.path }}
    port: {{ .svc.probes.port | default "http" }}
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
{{- end }}
{{- end }}

{{- define "kodus-common.imagePullSecrets" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "kodus-common.waitForDeps" -}}
{{- $pgHost := "" }}{{- $pgPort := "5432" }}
{{- if eq .Values.postgres.mode "bundled" }}{{- $pgHost = printf "%s-postgres" .Release.Name }}
{{- else if eq .Values.postgres.mode "operator" }}{{- $pgHost = printf "%s-postgres-rw" .Release.Name }}
{{- else }}{{- $pgHost = .Values.postgres.external.host | toString }}{{- $pgPort = .Values.postgres.external.port | default 5432 | toString }}{{- end }}
{{- $mgHost := "" }}{{- $mgPort := "27017" }}
{{- if eq .Values.mongodb.mode "bundled" }}{{- $mgHost = printf "%s-mongodb" .Release.Name }}
{{- else if eq .Values.mongodb.mode "operator" }}{{- $mgHost = printf "%s-mongodb-svc" .Release.Name }}
{{- else }}{{- $mgHost = .Values.mongodb.external.host | toString }}{{- $mgPort = .Values.mongodb.external.port | default 27017 | toString }}{{- end }}
- name: wait-for-deps
  image: {{ include "kodus-common.regPrefix" . }}{{ .Values.waitForDeps.image | default "busybox:1.37.0" }}
  command:
    - sh
    - -c
    - |
      until nc -z {{ $pgHost }} {{ $pgPort }}; do echo "waiting for postgres..."; sleep 2; done
      until nc -z {{ $mgHost }} {{ $mgPort }}; do echo "waiting for mongodb..."; sleep 2; done
      {{- if ne .Values.rabbitmq.mode "external" }}
      until nc -z {{ .Release.Name }}-rabbitmq 5672; do echo "waiting for rabbitmq..."; sleep 2; done
      {{- end }}
  resources:
    requests: { cpu: 10m, memory: 16Mi }
    limits:   { cpu: 50m, memory: 32Mi }
  securityContext:
    runAsNonRoot: true
    {{- if ne .Values.platform "openshift" }}
    runAsUser: 65534
    {{- end }}
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
{{- end }}
