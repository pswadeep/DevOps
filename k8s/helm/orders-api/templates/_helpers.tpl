{{- define "app.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "app.selector" -}}
app.kubernetes.io/name: {{ .Release.Name }}
{{- if .Values.color }}
color: {{ .Values.color }}
{{- end }}
{{- end -}}
