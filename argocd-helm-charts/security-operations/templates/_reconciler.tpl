{{/*
  Pod template shared by the reconciler CronJob, its Argo CD hook Jobs and the
  long-running Deployment (reconciler.mode: deployment).
  (dict "root" $ "hook" bool "long" bool): hook runs pass --exit-zero, so objects
  that cannot be reconciled yet (a component still starting) do not fail the
  sync; long runs reconcile every reconciler.interval and serve metrics.
*/}}
{{- define "secops.reconciler.pod" -}}
{{- $hook := .hook -}}
{{- $long := .long -}}
{{- with .root -}}
{{- $r := .Values.reconciler -}}
metadata:
  labels:
    app.kubernetes.io/name: siem-reconciler
    app.kubernetes.io/instance: {{ .Release.Name }}
    {{- if $long }}
    # Selects the long-running pod only (Service siem-reconciler-metrics).
    security-operations.kubeaid.io/reconciler-mode: deployment
    {{- end }}
  annotations:
    checksum/config: {{ include (print .Template.BasePath "/tenants-configmaps.yaml") . | sha256sum }}
spec:
  serviceAccountName: siem-reconciler
  restartPolicy: {{ if $long }}Always{{ else }}Never{{ end }}
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
        {{- if $long }}
        - --interval={{ $r.interval }}
        - --metrics-addr=:{{ $r.metricsPort }}
        {{- end }}
      {{- if $long }}
      ports:
        - name: metrics
          containerPort: {{ $r.metricsPort }}
          protocol: TCP
      livenessProbe:
        httpGet:
          path: /healthz
          port: metrics
        periodSeconds: 30
      readinessProbe:
        httpGet:
          path: /healthz
          port: metrics
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
        {{- if include "secops.caSecret" . }}
        - name: soc-ca
          mountPath: /etc/soc-ca
          readOnly: true
        {{- end }}
        {{- if (index .Values "kubesoc-content").enabled }}
        # Detection content (components.content in tenants.json).
        - name: content
          mountPath: /etc/kubesoc-content
          readOnly: true
        {{- if .Values.velociraptor.enabled }}
        - name: content-core-artifacts
          mountPath: /etc/kubesoc-content-core/velociraptor
          readOnly: true
        {{- end }}
        {{- end }}
  volumes:
    - name: config
      configMap:
        name: siem-tenants
    {{- with include "secops.caSecret" . }}
    # CA of the managers' and indexers' certificates (tls in values.yaml). Optional,
    # so a hook run before cert-manager has issued it still starts; the Wazuh
    # components then report the missing file.
    - name: soc-ca
      secret:
        secretName: {{ . }}
        optional: true
        items:
          - key: ca.crt
            path: ca.crt
    {{- if (index .Values "kubesoc-content").enabled }}
    - name: content
      configMap:
        name: kubesoc-content
    {{- if .Values.velociraptor.enabled }}
    - name: content-core-artifacts
      configMap:
        name: velociraptor-artifacts
    {{- end }}
    {{- end }}
{{- end }}
{{- end }}
