{{- define "blinkidVerify.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "blinkidVerify.name" -}}
{{- default .Chart.Name .Values.blinkIdVerify.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "blinkidVerify.fullname" -}}
{{- if .Values.blinkIdVerify.fullnameOverride -}}
{{- .Values.blinkIdVerify.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "blinkidVerify.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "blinkidVerify.labels" -}}
app.kubernetes.io/name: {{ include "blinkidVerify.name" . }}
helm.sh/chart: {{ include "blinkidVerify.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "blinkidVerify.serviceAccountName" -}}
{{- if .Values.blinkIdVerify.serviceAccount.create -}}
{{- default (include "blinkidVerify.fullname" .) .Values.blinkIdVerify.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.blinkIdVerify.serviceAccount.name -}}
{{- end -}}
{{- end -}}
