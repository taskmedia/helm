{{- define "outprint.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}{{ .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else -}}{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end -}}

{{- define "outprint.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: outprint
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* call with (dict "root" . "component" "worker") */}}
{{- define "outprint.selector" -}}
app.kubernetes.io/name: outprint
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "outprint.image" -}}
{{ .repository }}:{{ .tag | default .appVersion }}
{{- end -}}

{{- define "outprint.tokenSecretName" -}}
{{- default (printf "%s-worker-token" (include "outprint.fullname" .)) .Values.workerToken.existingSecret -}}
{{- end -}}

{{- define "outprint.tokenEnv" -}}
{{- if .Values.workerToken.enabled }}
- name: OUTPRINT_WORKER_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ include "outprint.tokenSecretName" . }}
      key: token
{{- end }}
{{- end -}}

{{- define "outprint.extraEnv" -}}
{{- range $k, $v := . }}
- name: {{ $k }}
  value: {{ $v | quote }}
{{- end }}
{{- end -}}

{{- define "outprint.containerSecurity" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: [ALL]
{{- end -}}

{{- define "outprint.podSecurity" -}}
runAsNonRoot: true
runAsUser: {{ .uid }}
runAsGroup: {{ .uid }}
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{/*
The Git sources as JSON: the shorthand packages.git (name "default") followed by
packages.sources. Checks names and URLs.
*/}}
{{- define "outprint.packagesSources" -}}
{{- $out := list -}}
{{- $names := dict -}}
{{- if .Values.packages.git.url -}}
{{- $g := .Values.packages.git -}}
{{- $out = append $out (dict "name" "default" "url" $g.url "ref" $g.ref "commit" $g.commit "path" (trimAll "/" $g.path) "sshKeySecret" $g.sshKeySecret) -}}
{{- $_ := set $names "default" true -}}
{{- end -}}
{{- range .Values.packages.sources -}}
{{- $name := required "packages.sources[].name is required" .name -}}
{{- if not (regexMatch "^[a-z0-9][a-z0-9-]*$" $name) -}}
{{- fail (printf "packages.sources: name %q must match ^[a-z0-9][a-z0-9-]*$" $name) -}}
{{- end -}}
{{- if hasKey $names $name -}}
{{- fail (printf "packages.sources: name %q is used twice (the shorthand packages.git is named \"default\")" $name) -}}
{{- end -}}
{{- $_ := set $names $name true -}}
{{- $g := required (printf "packages.sources[%s].git is required" $name) .git -}}
{{- $url := required (printf "packages.sources[%s].git.url is required" $name) $g.url -}}
{{- $out = append $out (dict "name" $name "url" $url "ref" (default "main" $g.ref) "commit" (default "" $g.commit) "path" (trimAll "/" (default "" $g.path)) "sshKeySecret" (default "" $g.sshKeySecret)) -}}
{{- end -}}
{{- toJson $out -}}
{{- end -}}

{{/* The packages source in use: git, image, existingClaim or empty. At most one may be set. */}}
{{- define "outprint.packagesSource" -}}
{{- $sources := list -}}
{{- if gt (len (fromJsonArray (include "outprint.packagesSources" .))) 0 }}{{ $sources = append $sources "git" }}{{ end -}}
{{- if .Values.packages.image.reference }}{{ $sources = append $sources "image" }}{{ end -}}
{{- if .Values.packages.existingClaim }}{{ $sources = append $sources "existingClaim" }}{{ end -}}
{{- if gt (len $sources) 1 -}}
{{- fail (printf "packages: set only one kind of source, got %s" (join ", " $sources)) -}}
{{- end -}}
{{- first (append $sources "") -}}
{{- end -}}

{{/* Folder that holds templates/ and configurations/ inside the packages mount. */}}
{{- define "outprint.packagesRoot" -}}
{{- if eq (include "outprint.packagesSource" .) "git" -}}
/packages/current
{{- else -}}
{{- printf "/packages/%s" (trimAll "/" .Values.packages.path) | trimSuffix "/" -}}
{{- end -}}
{{- end -}}

{{- define "outprint.packagesClaimName" -}}
{{- default (printf "%s-packages" (include "outprint.fullname" .)) .Values.packages.existingClaim -}}
{{- end -}}

{{/* Env for Gateway and Worker; the env vars win over the service config file. */}}
{{- define "outprint.packagesEnv" -}}
{{- if include "outprint.packagesSource" . }}
- name: OUTPRINT_TEMPLATES_ROOT
  value: {{ printf "%s/templates" (include "outprint.packagesRoot" .) | quote }}
- name: OUTPRINT_CONFIGURATIONS_ROOT
  value: {{ printf "%s/configurations" (include "outprint.packagesRoot" .) | quote }}
{{- end }}
{{- end -}}

{{- define "outprint.packagesVolumeMount" -}}
{{- if include "outprint.packagesSource" . }}
- { name: packages, mountPath: /packages, readOnly: true }
{{- end }}
{{- end -}}

{{- define "outprint.packagesVolume" -}}
{{- $source := include "outprint.packagesSource" . -}}
{{- if eq $source "image" }}
- name: packages
  image:
    reference: {{ .Values.packages.image.reference | quote }}
    pullPolicy: {{ .Values.packages.image.pullPolicy }}
{{- else if $source }}
- name: packages
  persistentVolumeClaim:
    claimName: {{ include "outprint.packagesClaimName" . }}
    readOnly: true
{{- end }}
{{- end -}}

{{/* Gateway and Worker wait here until the first sync has produced packages. */}}
{{- define "outprint.packagesWait" -}}
{{- if eq (include "outprint.packagesSource" .) "git" }}
initContainers:
  - name: wait-for-packages
    image: {{ include "outprint.image" (dict "repository" .Values.image.repository "tag" .Values.image.tag "appVersion" .Chart.AppVersion) | quote }}
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    command: ["sh", "-c", "until [ -d /packages/current/templates ] && [ -d /packages/current/configurations ]; do echo waiting for packages; sleep 2; done"]
    securityContext:
      {{- include "outprint.containerSecurity" . | nindent 6 }}
    resources:
      requests: {cpu: 10m, memory: 16Mi}
      limits: {cpu: 100m, memory: 32Mi}
    volumeMounts:
      - { name: packages, mountPath: /packages, readOnly: true }
{{- end }}
{{- end -}}

{{/* Minutes (5m) and hours (2h) become a cron expression; anything else is taken as one. */}}
{{- define "outprint.packagesSchedule" -}}
{{- if regexMatch "^[0-9]+m$" . -}}
*/{{ trimSuffix "m" . }} * * * *
{{- else if regexMatch "^[0-9]+h$" . -}}
0 */{{ trimSuffix "h" . }} * * *
{{- else -}}
{{ . }}
{{- end -}}
{{- end -}}
