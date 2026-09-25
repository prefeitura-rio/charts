{{- define "kodus-common.dbEnv" -}}
{{- if eq .Values.postgres.mode "bundled" }}
- name: API_PG_DB_HOST
  value: {{ printf "%s-postgres" .Release.Name | quote }}
- name: API_PG_DB_PORT
  value: "5432"
- name: API_PG_DB_USERNAME
  value: {{ .Values.postgres.bundled.username | quote }}
- name: API_PG_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-postgres-secret" .Release.Name }}
      key: password
- name: API_PG_DB_DATABASE
  value: {{ .Values.postgres.bundled.database | quote }}
{{- else if eq .Values.postgres.mode "operator" }}
- name: API_PG_DB_HOST
  value: {{ printf "%s-postgres-rw" .Release.Name | quote }}
- name: API_PG_DB_PORT
  value: "5432"
- name: API_PG_DB_USERNAME
  value: {{ .Values.postgres.operator.owner | quote }}
- name: API_PG_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-postgres-app" .Release.Name }}
      key: password
- name: API_PG_DB_DATABASE
  value: {{ .Values.postgres.operator.database | quote }}
{{- else }}
- name: API_PG_DB_HOST
  value: {{ .Values.postgres.external.host | quote }}
- name: API_PG_DB_PORT
  value: {{ .Values.postgres.external.port | default 5432 | quote }}
- name: API_PG_DB_USERNAME
  value: {{ .Values.postgres.external.username | quote }}
- name: API_PG_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ required "postgres.external.existingSecret is required when postgres.mode=external" .Values.postgres.external.existingSecret }}
      key: {{ .Values.postgres.external.passwordKey | default "password" }}
- name: API_PG_DB_DATABASE
  value: {{ .Values.postgres.external.database | quote }}
{{- end }}
{{- if eq .Values.mongodb.mode "bundled" }}
- name: API_MG_DB_HOST
  value: {{ printf "%s-mongodb" .Release.Name | quote }}
- name: API_MG_DB_PORT
  value: "27017"
- name: API_MG_DB_USERNAME
  value: {{ .Values.mongodb.bundled.username | quote }}
- name: API_MG_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-mongodb-secret" .Release.Name }}
      key: password
- name: API_MG_DB_DATABASE
  value: {{ .Values.mongodb.bundled.database | quote }}
{{- else if eq .Values.mongodb.mode "operator" }}
- name: API_MG_DB_HOST
  value: {{ printf "%s-mongodb-svc" .Release.Name | quote }}
- name: API_MG_DB_PORT
  value: "27017"
- name: API_MG_DB_USERNAME
  value: {{ .Values.mongodb.operator.username | quote }}
- name: API_MG_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-mongodb-password" .Release.Name }}
      key: password
- name: API_MG_DB_DATABASE
  value: {{ .Values.mongodb.operator.database | quote }}
{{- else }}
- name: API_MG_DB_HOST
  value: {{ .Values.mongodb.external.host | quote }}
- name: API_MG_DB_PORT
  value: {{ .Values.mongodb.external.port | default 27017 | quote }}
- name: API_MG_DB_USERNAME
  value: {{ .Values.mongodb.external.username | quote }}
- name: API_MG_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ required "mongodb.external.existingSecret is required when mongodb.mode=external" .Values.mongodb.external.existingSecret }}
      key: {{ .Values.mongodb.external.passwordKey | default "password" }}
- name: API_MG_DB_DATABASE
  value: {{ .Values.mongodb.external.database | quote }}
{{- end }}
{{- end }}

{{- define "kodus-common.rabbitmqEnv" -}}
{{- if and (eq .Values.rabbitmq.mode "bundled") .Values.rabbitmq.bundled.password (not (regexMatch "^[A-Za-z0-9]+$" .Values.rabbitmq.bundled.password)) }}
{{- fail "rabbitmq.bundled.password must contain only letters and numbers" }}
{{- end }}
{{- if eq .Values.rabbitmq.mode "bundled" }}
- name: RABBITMQ_USER
  value: {{ .Values.rabbitmq.bundled.username | quote }}
- name: RABBITMQ_PASS
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-rabbitmq-secret" .Release.Name }}
      key: password
- name: API_RABBITMQ_URI
  value: "amqp://$(RABBITMQ_USER):$(RABBITMQ_PASS)@{{ .Release.Name }}-rabbitmq:5672/kodus-ai"
{{- else if eq .Values.rabbitmq.mode "operator" }}
- name: RABBITMQ_USER
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-rabbitmq-default-user" .Release.Name }}
      key: username
- name: RABBITMQ_PASS
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-rabbitmq-default-user" .Release.Name }}
      key: password
- name: API_RABBITMQ_URI
  value: "amqp://$(RABBITMQ_USER):$(RABBITMQ_PASS)@{{ .Release.Name }}-rabbitmq:5672/kodus-ai"
{{- else }}
- name: API_RABBITMQ_URI
  valueFrom:
    secretKeyRef:
      name: {{ required "rabbitmq.external.existingSecret is required when rabbitmq.mode=external" .Values.rabbitmq.external.existingSecret }}
      key: {{ .Values.rabbitmq.external.uriKey | default "uri" }}
{{- end }}
{{- end }}

{{- define "kodus-common.appSecretsEnv" -}}
{{- $secretName := default (printf "%s-secrets" .Release.Name) .Values.global.existingSecret -}}
{{- range $key := list "API_JWT_SECRET" "API_JWT_REFRESH_SECRET" "WEB_NEXTAUTH_SECRET" "NEXTAUTH_SECRET" "API_CRYPTO_KEY" "CODE_MANAGEMENT_SECRET" }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ $key }}
{{- end }}
{{- range $key := list "CODE_MANAGEMENT_WEBHOOK_TOKEN" "API_OPEN_AI_API_KEY" "API_MORPHLLM_API_KEY" "API_E2B_KEY" "API_MCP_MANAGER_JWT_SECRET" "API_MCP_MANAGER_ENCRYPTION_SECRET" "API_GITHUB_CLIENT_SECRET" "API_GITHUB_PRIVATE_KEY" "WEB_OAUTH_GITHUB_CLIENT_SECRET" }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ $key }}
      optional: true
{{- end }}
{{- end }}
