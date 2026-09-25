{{/*
  Pod template shared by the reconciler CronJob and its Argo CD hook Jobs.
  (dict "root" $ "hook" bool): hook runs pass --exit-zero, so objects that
  cannot be reconciled yet (a component still starting) do not fail the sync.
*/}}
{{- define "secops.reconciler.pod" -}}
{{- $hook := .hook -}}
{{- with .root -}}
{{- $r := .Values.reconciler -}}
metadata:
  labels:
    app.kubernetes.io/name: siem-reconciler
    app.kubernetes.io/instance: {{ .Release.Name }}
  annotations:
    checksum/config: {{ include (print .Template.BasePath "/tenants-configmaps.yaml") . | sha256sum }}
spec:
  serviceAccountName: siem-reconciler
  restartPolicy: Never
  {{- with $r.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $r.hostAliases }}
  hostAliases:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: reconciler
      image: "{{ $r.image.repository }}:{{ required "reconciler.image.tag is required when reconciler.enabled" $r.image.tag }}"
      imagePullPolicy: {{ $r.image.pullPolicy }}
      args:
        - --config
        - /etc/siem/tenants.json
        - --dry-run={{ $r.dryRun }}
        {{- if $hook }}
        - --exit-zero
        {{- end }}
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      resources:
        {{- toYaml $r.resources | nindent 8 }}
      volumeMounts:
        - name: config
          mountPath: /etc/siem
          readOnly: true
  volumes:
    - name: config
      configMap:
        name: siem-tenants
{{- end }}
{{- end }}
