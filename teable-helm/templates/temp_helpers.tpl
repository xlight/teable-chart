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
