{{- define "kodus-common.podSecurityContext" -}}
runAsNonRoot: true
{{- if not (kindIs "invalid" .Values.podSecurityContext.fsGroup) }}
fsGroup: {{ .Values.podSecurityContext.fsGroup }}
{{- end }}
seccompProfile:
  type: {{ .Values.podSecurityContext.seccompProfile.type | default "RuntimeDefault" }}
{{- end }}

{{- define "kodus-common.containerSecurityContext" -}}
runAsNonRoot: true
readOnlyRootFilesystem: {{ .Values.containerSecurityContext.readOnlyRootFilesystem | default true }}
allowPrivilegeEscalation: false
capabilities:
  drop:
    - ALL
{{- end }}

{{- define "kodus-common.datastorePodSecurityContext" -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- if ne .Values.platform "openshift" }}
fsGroup: 999
runAsUser: 999
{{- end }}
{{- end }}

{{- define "kodus-common.tmpVolumeMount" -}}
- name: tmp
  mountPath: /tmp
{{- end }}

{{- define "kodus-common.tmpVolume" -}}
- name: tmp
  emptyDir:
    sizeLimit: 100Mi
{{- end }}
