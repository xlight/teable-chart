{{/*
Expand the name of the chart.
*/}}
{{- define "teable.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "teable.fullname" -}}
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
{{- define "teable.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "teable.labels" -}}
helm.sh/chart: {{ include "teable.chart" . }}
{{ include "teable.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "teable.selectorLabels" -}}
app.kubernetes.io/name: {{ include "teable.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "teable.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "teable.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate database URL
*/}}
{{- define "teable.databaseUrl" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgresql://postgres:%s@%s-postgresql:5432/%s" .Values.postgresql.auth.postgresPassword .Release.Name .Values.postgresql.auth.database }}
{{- else }}
{{- .Values.database.url | default "postgresql://postgres:password@localhost:5432/teable" }}
{{- end }}
{{- end }}

{{/*
Generate Redis URI
*/}}
{{- define "teable.redisUri" -}}
{{- if .Values.redis.enabled }}
{{- if .Values.redis.auth.enabled }}
{{- printf "redis://:%s@%s-redis-master:6379/0" .Values.redis.auth.password .Release.Name }}
{{- else }}
{{- printf "redis://%s-redis-master:6379/0" .Release.Name }}
{{- end }}
{{- else }}
{{- .Values.cache.redisUri | default "redis://localhost:6379/0" }}
{{- end }}
{{- end }}

{{/*
Generate MinIO internal endpoint
*/}}
{{- define "teable.minioInternalEndpoint" -}}
{{- if .Values.minio.enabled }}
{{- printf "%s-minio" .Release.Name }}
{{- else }}
{{- .Values.storage.minio.internalEndpoint | default "minio.default.svc.cluster.local" }}
{{- end }}
{{- end }}

{{/*
Generate MinIO access key
*/}}
{{- define "teable.minioAccessKey" -}}
{{- if .Values.minio.enabled }}
{{- .Values.minio.rootUser }}
{{- else }}
{{- .Values.storage.minio.accessKey | default "minioadmin" }}
{{- end }}
{{- end }}

{{/*
Generate MinIO secret key
*/}}
{{- define "teable.minioSecretKey" -}}
{{- if .Values.minio.enabled }}
{{- .Values.minio.rootPassword }}
{{- else }}
{{- .Values.storage.minio.secretKey | default "minioadmin" }}
{{- end }}
{{- end }}

{{/*
Generate MinIO internal port
*/}}
{{- define "teable.minioInternalPort" -}}
{{- if .Values.minio.enabled }}
{{- .Values.minio.service.ports.api | toString }}
{{- else }}
{{- .Values.storage.minio.internalPort | default "9000" }}
{{- end }}
{{- end }}
