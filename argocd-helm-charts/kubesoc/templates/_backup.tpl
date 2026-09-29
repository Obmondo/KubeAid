{{/*
  Helpers of the backup block (values.yaml `backup`, README "Backups").
*/}}

{{/* true while the backup block is on. */}}
{{- define "secops.backup.enabled" -}}
{{- if (.Values.backup | default dict).enabled -}}true{{- end -}}
{{- end -}}

{{/*
  Namespaces the SOC's state lives in: this one and every tenant's, as a YAML
  list. backup.velero.includedNamespaces replaces it.
*/}}
{{- define "secops.backup.namespaces" -}}
{{- with .Values.backup.velero.includedNamespaces -}}
{{- toYaml . -}}
{{- else -}}
{{- $out := list .Release.Namespace -}}
{{- range include "secops.tenants" . | fromJsonArray -}}
{{- $out = append $out .namespace -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}
{{- end -}}

{{/* Index patterns the snapshots and the shard-copy setting cover, comma separated. */}}
{{- define "secops.backup.indices" -}}
{{- with .Values.backup.opensearch.indices -}}
{{- join "," . -}}
{{- else -}}
wazuh-alerts-*,wazuh-archives-*
{{- end -}}
{{- end -}}

{{/*
  Body of PUT _snapshot/<repository>, as JSON.

  fs: the shared ReadWriteMany volume every indexer node mounts, which the wazuh
  chart's indexer.snapshot renders (it also sets path.repo; without that the
  indexer refuses the repository).

  s3: needs the repository-s3 plugin in the indexer image and the bucket
  credentials in the indexer's keystore (s3.client.default.access_key and
  .secret_key) - neither of which this chart can put there, see the README.
*/}}
{{- define "secops.backup.repositoryBody" -}}
{{- $o := .Values.backup.opensearch -}}
{{- if eq $o.type "fs" -}}
{{- dict "type" "fs" "settings" (dict "location" $o.fs.location "compress" true) | toJson -}}
{{- else if eq $o.type "s3" -}}
{{- $s := .Values.backup.objectStore -}}
{{- $settings := dict "bucket" $s.bucket "base_path" (printf "%s/opensearch" $s.basePath) "compress" true -}}
{{- with $s.endpoint -}}{{- $_ := set $settings "endpoint" . -}}{{- end -}}
{{- with $s.region -}}{{- $_ := set $settings "region" . -}}{{- end -}}
{{- if $s.pathStyleAccess -}}{{- $_ := set $settings "path_style_access" true -}}{{- end -}}
{{- dict "type" "s3" "settings" $settings | toJson -}}
{{- else -}}
{{- fail (printf "backup.opensearch.type %q: use fs or s3" $o.type) -}}
{{- end -}}
{{- end -}}

{{/* Body of PUT _plugins/_sm/policies/<name>, as JSON. */}}
{{- define "secops.backup.policyBody" -}}
{{- $o := .Values.backup.opensearch -}}
{{- $p := $o.policy -}}
{{- $creation := dict "schedule" (dict "cron" (dict "expression" $p.schedule "timezone" $p.timezone)) -}}
{{- $deletion := dict "schedule" (dict "cron" (dict "expression" "0 3 * * *" "timezone" $p.timezone))
    "condition" (dict "max_age" (printf "%dd" (int $o.retentionDays)) "max_count" (int $p.maxCount)) -}}
{{- dict "description" "kubesoc alert index snapshots"
    "creation" $creation
    "deletion" $deletion
    "snapshot_config" (dict
      "repository" $o.repository
      "indices" (include "secops.backup.indices" .)
      "ignore_unavailable" true
      "include_global_state" false
      "date_format" "yyyy-MM-dd-HH:mm") | toJson -}}
{{- end -}}

{{/* Image of the snapshot CronJob: backup.opensearch.image, else the central indexer's. */}}
{{- define "secops.backup.opensearchImage" -}}
{{- $i := .Values.backup.opensearch.image -}}
{{- $indexer := ((.Values.wazuh.wazuh | default dict).indexer | default dict).images | default dict -}}
{{- $repository := $i.repository | default $indexer.repository | default "wazuh/wazuh-indexer" -}}
{{- $tag := $i.tag | default $indexer.tag | default "" -}}
{{- if not $tag -}}{{- fail "backup.opensearch.image.tag is required when the central Wazuh indexer is disabled" -}}{{- end -}}
{{- printf "%s:%s" $repository (toString $tag) -}}
{{- end -}}

{{/*
  Pod template of one indexer's snapshot CronJob.
  (dict "root" $ "namespace" <ns> "url" <indexer url> "credSecret" <secret name>)
*/}}
{{- define "secops.backup.snapshotPod" -}}
{{- $namespace := .namespace -}}
{{- $url := .url -}}
{{- $credSecret := .credSecret -}}
{{- with .root -}}
{{- $o := .Values.backup.opensearch -}}
{{- $snapshotOnRun := $o.snapshotOnRun -}}
{{- if kindIs "invalid" $snapshotOnRun -}}{{- $snapshotOnRun = not $o.policy.enabled -}}{{- end -}}
metadata:
  labels:
    app.kubernetes.io/name: kubesoc-indexer-snapshot
    app.kubernetes.io/instance: {{ .Release.Name }}
    kubesoc.io/backup: opensearch-snapshot
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: snapshot
      image: {{ include "secops.backup.opensearchImage" . | quote }}
      imagePullPolicy: {{ $o.image.pullPolicy }}
      command: ["/bin/sh", "/scripts/opensearch-snapshot.sh"]
      env:
        - name: INDEXER_URL
          value: {{ $url | quote }}
        - name: REPOSITORY
          value: {{ $o.repository | quote }}
        - name: REPOSITORY_BODY
          value: {{ include "secops.backup.repositoryBody" . | quote }}
        - name: SNAPSHOT_PREFIX
          value: {{ $o.snapshotPrefix | quote }}
        - name: INDICES
          value: {{ include "secops.backup.indices" . | quote }}
        - name: RETENTION_DAYS
          value: {{ $o.retentionDays | quote }}
        - name: SNAPSHOT_ON_RUN
          value: {{ $snapshotOnRun | quote }}
        {{- if not (kindIs "invalid" $o.numberOfReplicas) }}
        - name: NUMBER_OF_REPLICAS
          value: {{ $o.numberOfReplicas | quote }}
        {{- end }}
        {{- if $o.policy.enabled }}
        - name: POLICY_NAME
          value: {{ $o.policy.name | quote }}
        - name: POLICY_BODY
          value: {{ include "secops.backup.policyBody" . | quote }}
        {{- end }}
        - name: INDEXER_USERNAME
          valueFrom:
            secretKeyRef:
              name: {{ $credSecret }}
              key: INDEXER_USERNAME
        - name: INDEXER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ $credSecret }}
              key: INDEXER_PASSWORD
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      resources:
        {{- toYaml $o.resources | nindent 8 }}
      volumeMounts:
        - name: scripts
          mountPath: /scripts
          readOnly: true
        - name: tmp
          mountPath: /tmp
        {{- if include "secops.caSecret" . }}
        - name: soc-ca
          mountPath: /etc/soc-ca
          readOnly: true
        {{- end }}
  volumes:
    - name: scripts
      configMap:
        name: kubesoc-backup-scripts
    - name: tmp
      emptyDir: {}
    {{- with include "secops.caSecret" . }}
    # CA of the indexers' certificates; without it the script does not verify.
    - name: soc-ca
      secret:
        secretName: {{ . }}
        optional: true
        items:
          - key: ca.crt
            path: ca.crt
    {{- end }}
{{- end }}
{{- end -}}
