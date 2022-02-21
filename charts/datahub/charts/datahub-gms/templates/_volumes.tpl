{{ define "wmf.volumes" }}
{{- $has_volumes := 0 -}}
{{ if (.Values.tls.enabled) }}
  {{- $has_volumes = 1 -}}
{{ else if .Values.main_app.volumes }}
  {{- $has_volumes = 1 -}}
{{ else if (and .Values.monitoring.enabled .Values.monitoring.uses_statsd) }}
  {{- $has_volumes = 1 -}}
{{ else }}
  {{/*Yes this is redundant but it's more readable*/}}
  {{- $has_volumes = 0 -}}
{{end}}
{{ if eq $has_volumes 1 }}
{{- include "tls.volume" . }}
# Additional app-specific volumes.
  {{- with .Values.main_app.volumes }}
    {{- toYaml . }}
  {{- end }}
{{ else }}
[]
{{- end }}
{{end}}
