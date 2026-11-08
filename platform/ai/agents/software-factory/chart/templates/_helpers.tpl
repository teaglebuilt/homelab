{{- define "software-factory.fullname" -}}
{{- printf "%s-%s" .release .role | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "software-factory.labels" -}}
app.kubernetes.io/name: software-factory
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/part-of: software-factory
software-factory.kagent.dev/role: {{ .role | quote }}
{{- end -}}
