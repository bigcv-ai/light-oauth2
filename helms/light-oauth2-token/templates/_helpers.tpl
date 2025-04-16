{{/*
Expand the name of the chart.
*/}}
{{- define "light-oauth2-code.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "light-oauth2-code.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "light-oauth2-code.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "light-oauth2-code.labels" -}}
helm.sh/chart: {{ include "light-oauth2-code.chart" . }}
{{ include "light-oauth2-code.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "light-oauth2-code.selectorLabels" -}}
app.kubernetes.io/name: {{ include "light-oauth2-code.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "light-oauth2-code.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "light-oauth2-code.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Convert YAML config to environment variables
*/}}
{{- define "light-oauth2-code.configToEnv" -}}
{{- $file := .Files.Get (printf "config/%s/%s" .Values.environment .) -}}
{{- if $file -}}
{{- $config := fromYaml $file -}}
{{- range $key, $value := $config -}}
{{- if kindIs "map" $value -}}
{{- range $subkey, $subvalue := $value -}}
{{- printf "%s_%s_%s: %s" (upper .) (upper $key) (upper $subkey) ($subvalue | quote) -}}
{{- end -}}
{{- else -}}
{{- printf "%s_%s: %s" (upper .) (upper $key) ($value | quote) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
