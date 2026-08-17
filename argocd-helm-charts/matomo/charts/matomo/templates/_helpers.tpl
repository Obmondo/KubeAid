{{/* Generate basic labels */}}
{{- define "matomo.labels" }}
  labels:
    app.kubernetes.io/name: {{ .name }}
    app.kubernetes.io/instance: {{ .instance }}
    app.kubernetes.io/component: {{ .component }}
    app.kubernetes.io/part-of: {{ .partOf }}
    app.kubernetes.io/managed-by: {{ .managedBy }}
{{- end }}

{{/*
Combined checksum of every ConfigMap this chart renders.

Kubernetes only rolls a Deployment/CronJob's pods when the pod template
itself changes; updating a ConfigMap's content does not by itself trigger
anything, so without a checksum baked into the pod template, `helm upgrade`
(or `kubectl apply`) updates the ConfigMap object but already-running pods
keep using the stale mounted file until they restart for some unrelated
reason. This is deliberately chart-wide (every ConfigMap template, not just
the ones a given workload happens to mount today) rather than computed
per-workload: simpler to keep correct than tracking which of the ~12
ConfigMap templates each workload mounts - that's exactly how this
annotation previously only covered configmap-matomo.yaml and silently
missed every ConfigMap added since (e.g. the php-fpm pool config).
*/}}
{{- define "matomo.configChecksum" -}}
{{- $ctx := . -}}
{{- $templates := list
  "configmap-matomo.yaml"
  "configmap-matomo-phpfpm.yaml"
  "configmap-matomo-phpfpm-tracker.yaml"
  "configmap-matomo-dashboard-php.yaml"
  "configmap-matomo-cronjob-php.yaml"
  "configmap-matomo-scheduledtasks-php.yaml"
  "configmap-nginx-matomo-dashboard.yaml"
  "configmap-nginx-matomo-tracker.yaml"
  "configmap-supervisor-tracker.yaml"
  "configmap-supervisor-queuedtrackingmonitor.yaml"
  "configmap-supervisor-queuedtrackingprocess.yaml"
  "configmap-pre-upgrade-extras.yaml"
  "configmaps-extras.yaml"
-}}
{{- $rendered := "" -}}
{{- range $templates -}}
{{- $rendered = print $rendered (include (print $ctx.Template.BasePath "/" .) $ctx) -}}
{{- end -}}
{{- $rendered | sha256sum -}}
{{- end -}}

{{/*
Standard pod-template annotations: the combined config checksum above, plus
the chart version and app version that rendered this pod. Bumping the chart
version alone (even with no rendered content change) also forces a restart,
as a second line of defense alongside the checksum. Include under
`annotations:` at the caller's indent, e.g.:
  annotations:
    (include "matomo.podAnnotations" . | indent 8, wrapped in {{ }})
*/}}
{{- define "matomo.podAnnotations" -}}
checksum/config: {{ include "matomo.configChecksum" . }}
helm.sh/chart-version: {{ .Chart.Version | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}

{{- define "matomo.images.pullSecrets" -}}
  {{- $pullSecrets := list }}

  {{- if .global }}
    {{- range .global.imagePullSecrets -}}
      {{- $pullSecrets = append $pullSecrets . -}}
    {{- end -}}
  {{- end -}}

  {{- range .images -}}
    {{- range .imagePullSecrets -}}
      {{- $pullSecrets = append $pullSecrets . -}}
    {{- end -}}
  {{- end -}}

  {{- if (not (empty $pullSecrets)) }}
imagePullSecrets:
    {{- range $pullSecrets }}
  - name: {{ . }}
    {{- end }}
  {{- end }}
{{- end -}}
{{- define "matomo.license" }}
{{- if .Values.matomo.license }}
- name: MATOMO_LICENSE
  valueFrom:
    secretKeyRef:
      name: {{ .Values.matomo.license.secretKeyRef.name }}
      key: {{ .Values.matomo.license.secretKeyRef.key }}
{{- end -}}
{{- end -}}
{{- define "matomo.initContainer" -}}
- name: matomo-init
  image: {{.Values.matomo.image}}
  securityContext:
    runAsUser: {{.Values.matomo.runAsUser}}
    privileged: false
    allowPrivilegeEscalation: false
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
  imagePullPolicy: Always
  env:
  - name: MATOMO_FIRST_USER_NAME
    value: {{.Values.matomo.dashboard.firstuser.username}}
  - name: MATOMO_FIRST_USER_EMAIL
    value: {{.Values.matomo.dashboard.firstuser.email}}
  - name: MATOMO_FIRST_USER_PASSWORD
    value: {{.Values.matomo.dashboard.firstuser.password}}
  - name: MATOMO_DB_HOST
    value: {{.Values.db.hostname}}
  - name: MATOMO_DB_NAME
    value: {{.Values.db.name}}
{{- if .Values.db.prefix }}
  - name: MATOMO_DB_PREFIX
    value: {{.Values.db.prefix}}
{{- end }}
  - name: MATOMO_DB_USERNAME
    value: {{.Values.db.username}}
  - name: MATOMO_DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ .Values.db.password.secretKeyRef.name }}
        key: {{ .Values.db.password.secretKeyRef.key }}
{{- include "matomo.license" . | nindent 2 }}
  command: [ 'sh' , '-c' , 'rsync -crlOt --no-owner --no-group --no-perms /usr/src/matomo/ /var/www/html/ && {{.Values.matomo.installCommand}}' ]
  {{- if .Values.matomo.initResources }}
  resources:
{{ toYaml .Values.matomo.initResources | indent 4 }}
  {{- end }}
  volumeMounts:
    - name: static-data
      mountPath: /var/www/html
    - name: matomo-configuration
      mountPath: /tmp/matomo/
      readOnly: true
{{- end -}}

{{- define "matomo.init" -}}
initContainers:
  {{- include "matomo.initContainer" . | nindent 2 }}
{{- end -}}

{{/*
Name of the PVC mounted at /var/www/html/js on the dashboard, tracker, and
regenerate-tagmanager pods. Either the one this chart creates
(matomo.tagManagerRegenerate.volume.create, the default) or a pre-existing
PVC supplied via matomo.tagManagerRegenerate.volume.existingClaim.
*/}}
{{- define "matomo.tagManagerJsClaimName" -}}
{{- if .Values.matomo.tagManagerRegenerate.volume.create -}}
matomo-tagmanager-js
{{- else -}}
{{- .Values.matomo.tagManagerRegenerate.volume.existingClaim -}}
{{- end -}}
{{- end -}}

{{/*
Guarded `tagmanager:regenerate-released-containers` invocation. TagManager
isn't in the chart's default install.json PluginsInstalled list (see
matomo.config), so on any site that's never activated it, this console
command doesn't exist yet - this must be a no-op rather than fail the
caller. Shared by matomo-warmup and the regenerate-tagmanager CronJob.
*/}}
{{- define "matomo.tagManagerRegenerateGuarded" -}}
if ./console list --raw 2>/dev/null | grep -q "^tagmanager:regenerate-released-containers "; then ./console tagmanager:regenerate-released-containers; fi
{{- end -}}

{{/*
Runs once after matomo-init (rsync + matomo:install), before php-fpm/nginx
start. `matomo:install --force` reconciles the DB schema/admin user/
install.json but does not itself fire the plugin-installed/update events
Matomo's own plugins (e.g. TagManager) hook to regenerate their generated
assets - those are normally left to fire lazily on the first web request(s)
after a (re)start. Since `static-data` is an emptyDir, that plugin-installed
bookkeeping is reset on every fresh pod, so without this step, concurrent
probes/traffic on every pod (re)start each independently pay for and race
that expensive regeneration (observed as repeated multi-second stalls in the
php-fpm slowlog, all bottoming out in TagManager::regenerateReleasedContainers()).
Running `core:update` here instead does that work once, synchronously, gated
behind pod readiness. The (also guarded) tagmanager regeneration itself is
only run here when matomo.tagManagerRegenerate is disabled; when it's
enabled, the regenerate-tagmanager CronJob owns that work instead, writing
into the shared PersistentVolumeClaim mounted at /var/www/html/js on the
dashboard/tracker containers, so redoing it here per-pod would be redundant.
*/}}
{{- define "matomo.warmupContainer" -}}
- name: matomo-warmup
  image: {{.Values.matomo.image}}
  securityContext:
    runAsUser: {{.Values.matomo.runAsUser}}
    privileged: false
    allowPrivilegeEscalation: false
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
  imagePullPolicy: Always
  env:
  - name: MATOMO_DB_HOST
    value: {{.Values.db.hostname}}
  - name: MATOMO_DB_NAME
    value: {{.Values.db.name}}
{{- if .Values.db.prefix }}
  - name: MATOMO_DB_PREFIX
    value: {{.Values.db.prefix}}
{{- end }}
  - name: MATOMO_DB_USERNAME
    value: {{.Values.db.username}}
  - name: MATOMO_DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ .Values.db.password.secretKeyRef.name }}
        key: {{ .Values.db.password.secretKeyRef.key }}
{{- include "matomo.license" . | nindent 2 }}
  command: [ 'sh' , '-c' , '{{.Values.matomo.warmupCommand}}{{ if not .Values.matomo.tagManagerRegenerate.enabled }} && {{ include "matomo.tagManagerRegenerateGuarded" . }}{{ end }}' ]
  {{- if .Values.matomo.warmupResources }}
  resources:
{{ toYaml .Values.matomo.warmupResources | indent 4 }}
  {{- end }}
  volumeMounts:
    - name: static-data
      mountPath: /var/www/html
{{- end -}}

{{/*
Ensures the baseline JS assets bundled in the Matomo image itself
(matomo.tagManagerRegenerate.seedSourcePath, e.g. piwik.js/piwik.min.js/
tracker.php/index.php - general tracker files, nothing TagManager-specific)
are present in the shared TagManager JS PersistentVolumeClaim (mounted at
/var/www/html/js on the dashboard/tracker main containers when
matomo.tagManagerRegenerate.enabled). TagManager's own generated container
files land in the same directory (via the regenerate-tagmanager CronJob),
but regenerating containers never restores these baseline files - only this
step does.

Deliberately NOT gated on "only if the shared volume is empty": the CronJob
and dashboard/tracker pods start independently, so if the CronJob happens to
write its first container file before any pod has ever run this step, the
volume is no longer empty, but the baseline files still wouldn't be there.
Instead this always runs on every pod start.

Also deliberately NOT a non-clobbering copy: seedSourcePath only ever
contains this fixed, image-shipped set of baseline files, never
TagManager's own generated container files (different names, same
directory) - so an unconditional overwrite can't touch TagManager's output,
and it's what makes a Matomo version upgrade actually take effect (a
no-clobber copy would leave a stale piwik.js/tracker.php/etc from whatever
version first happened to seed the volume in place forever).

Sources from the image directly (rather than this pod's own rsynced copy
under static-data) so this container doesn't need static-data mounted at
all.
*/}}
{{- define "matomo.seedTagManagerJsContainer" -}}
- name: matomo-seed-tagmanager-js
  image: {{.Values.matomo.image}}
  securityContext:
    runAsUser: {{.Values.matomo.runAsUser}}
    privileged: false
    allowPrivilegeEscalation: false
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
  imagePullPolicy: Always
  # -R (not -a/-p): this container runs as a non-root, non-owning uid, so it
  # can't preserve the source's ownership/permissions/timestamps on the
  # destination anyway (busybox cp errors on exactly that with -a) - we only
  # need the content there, not matching metadata. `&&` (not `;`) so a
  # genuine copy failure actually fails the init container instead of being
  # masked by the trailing echo.
  command: [ 'sh' , '-c' , 'cp -R {{ .Values.matomo.tagManagerRegenerate.seedSourcePath }}/. /shared-js/ && echo "baseline JS assets from {{ .Values.matomo.tagManagerRegenerate.seedSourcePath }} refreshed in shared TagManager JS volume"' ]
  {{- if .Values.matomo.tagManagerRegenerate.seedResources }}
  resources:
{{ toYaml .Values.matomo.tagManagerRegenerate.seedResources | indent 4 }}
  {{- end }}
  volumeMounts:
    - name: tagmanager-js
      mountPath: /shared-js
{{- end -}}

{{/*
initContainers for the dashboard and tracker: matomo-init, then
matomo-warmup, then (only when matomo.tagManagerRegenerate.enabled) the
one-time seed of the shared TagManager JS volume.
*/}}
{{- define "matomo.initWithWarmup" -}}
initContainers:
  {{- include "matomo.initContainer" . | nindent 2 }}
  {{- include "matomo.warmupContainer" . | nindent 2 }}
  {{- if .Values.matomo.tagManagerRegenerate.enabled }}
  {{- include "matomo.seedTagManagerJsContainer" . | nindent 2 }}
  {{- end }}
{{- end -}}

{{/*
matomo-init fails fast when the database is unreachable, so a Job would burn
its backoff retries while a fresh database is still provisioning. Bounded so
an unreachable database fails the Job instead of hanging it forever.
*/}}
{{- define "matomo.waitForDb" -}}
- name: wait-for-db
  image: {{.Values.matomo.image}}
  securityContext:
    runAsUser: {{.Values.matomo.runAsUser}}
    privileged: false
    allowPrivilegeEscalation: false
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
  imagePullPolicy: Always
  command:
    - bash
    - -c
    - |
      host={{.Values.db.hostname}}
      port={{.Values.db.port | default 3306}}
      for i in $(seq 1 180); do
        if (echo > /dev/tcp/$host/$port) 2>/dev/null; then
          echo "database $host:$port is reachable"
          exit 0
        fi
        echo "waiting for database $host:$port ($i/180)"
        sleep 5
      done
      echo "database $host:$port not reachable after 15 minutes, giving up"
      exit 1
  {{- if .Values.matomo.waitForDbResources }}
  resources:
{{ toYaml .Values.matomo.waitForDbResources | indent 4 }}
  {{- end }}
{{- end -}}

{{/*
matomo.probe renders a container probe with REPLACE (not merge) semantics.

Helm always deep-merges a user's values onto the chart's values.yaml, so a
partial override of a probe would be merged with the chart default and could
end up specifying two handler types (e.g. tcpSocket + exec), which Kubernetes
rejects. To make an override fully REPLACE the default, probe defaults are kept
out of values.yaml (each probe value defaults to {}) and supplied here instead:

  - a non-empty override is rendered verbatim and fully replaces the default
  - an empty override ({} / unset) falls back to the built-in default

Params (dict): "override" = the value from .Values, "default" = default probe
YAML rendered from one of the matomo.probe.default.* templates below.
*/}}
{{- define "matomo.probe" -}}
{{- if .override -}}
{{- toYaml .override -}}
{{- else -}}
{{- .default -}}
{{- end -}}
{{- end -}}

{{/* Default php-fpm container probes (dashboard + tracker matomo container). */}}
{{- define "matomo.probe.default.phpfpm.liveness" -}}
tcpSocket:
  port: 9000
initialDelaySeconds: 15
periodSeconds: 20
{{- end -}}
{{- define "matomo.probe.default.phpfpm.readiness" -}}
tcpSocket:
  port: 9000
initialDelaySeconds: 10
periodSeconds: 10
{{- end -}}

{{/* Default supervisord probes (cli, queuedtracking-monitor, queuedtracking-process). */}}
{{- define "matomo.probe.default.supervisord.liveness" -}}
exec:
  command:
  - /bin/sh
  - -c
  - "ps -A | grep supervisord"
initialDelaySeconds: 15
periodSeconds: 20
{{- end -}}
{{- define "matomo.probe.default.supervisord.readiness" -}}
exec:
  command:
  - /bin/sh
  - -c
  - "ps -A | grep supervisord"
initialDelaySeconds: 10
periodSeconds: 10
timeoutSeconds: 5
{{- end -}}

{{/* Default nginx probes. Liveness is shared; readiness differs per service. */}}
{{- define "matomo.probe.default.nginx.liveness" -}}
httpGet:
  scheme: HTTP
  path: /health
  port: 8080
initialDelaySeconds: 10
periodSeconds: 10
timeoutSeconds: 5
{{- end -}}
{{- define "matomo.probe.default.nginx.dashboard.readiness" -}}
httpGet:
  scheme: HTTP
  path: /index.php
  port: 8080
initialDelaySeconds: 10
periodSeconds: 10
timeoutSeconds: 20
{{- end -}}
{{- define "matomo.probe.default.nginx.tracker.readiness" -}}
httpGet:
  scheme: HTTP
  path: /matomo.js
  port: 8080
initialDelaySeconds: 10
periodSeconds: 10
timeoutSeconds: 5
{{- end -}}

{{/* Default php-fpm_exporter (fpm-metrics) sidecar probes (dashboard + tracker). */}}
{{- define "matomo.probe.default.exporter.liveness" -}}
tcpSocket:
  port: 9253
initialDelaySeconds: 15
periodSeconds: 20
{{- end -}}
{{- define "matomo.probe.default.exporter.readiness" -}}
tcpSocket:
  port: 9253
initialDelaySeconds: 10
periodSeconds: 10
{{- end -}}
