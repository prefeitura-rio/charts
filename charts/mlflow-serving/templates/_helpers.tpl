{{- define "model.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "pip.command" -}}
{{- if .Values.model.extraDependencies }}
{{- printf "%s %s %s" "pip install" (.Values.model.extraDependencies | join " ") "&&" }}
{{- else }}
{{- ""  }}
{{- end }}
{{- end }}