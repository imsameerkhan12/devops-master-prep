{{/*
  _helpers.tpl — reusable template snippets
  include "s3-lister.labels" .        → standard labels
  include "s3-lister.selectorLabels" . → selector labels (Deployment + Service match)
*/}}

{{- define "s3-lister.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "s3-lister.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
