{{- define "outprint.packagesSyncPod" }}
{{- $git := .Values.packages.git }}
{{- $sources := fromJsonArray (include "outprint.packagesSources" .) }}
{{- $name := printf "%s-packages" (include "outprint.fullname" .) }}
serviceAccountName: {{ $name }}
restartPolicy: Never
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
securityContext:
  seccompProfile:
    type: RuntimeDefault
initContainers:
  - name: sync
    image: {{ printf "%s:%s" $git.image.repository $git.image.tag | quote }}
    imagePullPolicy: {{ $git.image.pullPolicy }}
    command: ["sh", "/scripts/sync.sh"]
    securityContext:
      runAsUser: 0
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
        add: [CHOWN, DAC_OVERRIDE, FOWNER, SETUID, SETGID]
    resources:
      {{- toYaml $git.resources | nindent 6 }}
    volumeMounts:
      - { name: packages, mountPath: /packages }
      - { name: scripts, mountPath: /scripts, readOnly: true }
      {{- range $sources }}
      {{- if .sshKeySecret }}
      - { name: {{ printf "ssh-%s" .name }}, mountPath: {{ printf "/ssh/%s" .name | quote }}, readOnly: true }
      {{- end }}
      {{- end }}
  - name: validate
    image: {{ include "outprint.image" (dict "repository" .Values.image.repository "tag" .Values.image.tag "appVersion" .Chart.AppVersion) | quote }}
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    command: ["sh", "/scripts/validate.sh"]
    securityContext:
      {{- include "outprint.containerSecurity" . | nindent 6 }}
      runAsNonRoot: true
      runAsUser: 10001
      runAsGroup: 10001
    resources:
      requests: {cpu: 50m, memory: 64Mi}
      limits: {cpu: 500m, memory: 256Mi}
    volumeMounts:
      - { name: packages, mountPath: /packages, readOnly: true }
      - { name: scripts, mountPath: /scripts, readOnly: true }
      - { name: service-config, mountPath: /etc/outprint, readOnly: true }
      - { name: tmp, mountPath: /tmp }
containers:
  - name: activate
    image: {{ printf "%s:%s" $git.image.repository $git.image.tag | quote }}
    imagePullPolicy: {{ $git.image.pullPolicy }}
    command: ["sh", "/scripts/activate.sh"]
    env:
      - name: NAMESPACE
        valueFrom: { fieldRef: { fieldPath: metadata.namespace } }
      - { name: DEPLOYMENTS, value: {{ printf "%s-gateway %s-worker" (include "outprint.fullname" .) (include "outprint.fullname" .) | quote }} }
      - { name: KEEP_REVISIONS, value: {{ $git.keepRevisions | quote }} }
    securityContext:
      runAsUser: 0
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: [ALL]
        add: [CHOWN, DAC_OVERRIDE, FOWNER]
    resources:
      requests: {cpu: 10m, memory: 32Mi}
      limits: {cpu: 200m, memory: 128Mi}
    volumeMounts:
      - { name: packages, mountPath: /packages }
      - { name: scripts, mountPath: /scripts, readOnly: true }
      - { name: tmp, mountPath: /tmp }
volumes:
  - name: packages
    persistentVolumeClaim:
      claimName: {{ $name }}
  - name: scripts
    configMap:
      name: {{ $name }}-sync
  - name: service-config
    configMap:
      name: {{ include "outprint.fullname" . }}-service
  - name: tmp
    emptyDir: { sizeLimit: 64Mi }
  {{- range $sources }}
  {{- if .sshKeySecret }}
  - name: {{ printf "ssh-%s" .name }}
    secret:
      secretName: {{ .sshKeySecret }}
      defaultMode: 0400
  {{- end }}
  {{- end }}
{{- end }}
