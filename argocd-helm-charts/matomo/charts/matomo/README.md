# matomo

![Version: 12.0.19](https://img.shields.io/badge/Version-12.0.19-informational?style=flat-square) ![AppVersion: 5.12.0](https://img.shields.io/badge/AppVersion-5.12.0-informational?style=flat-square)

A Helm chart for Matomo

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| db.hostname | string | `"matomo-db-mysql"` | Database hostname. |
| db.name | string | `"matomo"` | Database name. |
| db.password.secretKeyRef.key | string | `"mysql-root-password"` | Key within the secret holding the database password. |
| db.password.secretKeyRef.name | string | `"matomo-db-mysql"` | Name of the secret holding the database password. |
| db.port | int | `3306` | Database port. |
| db.prefix | string | `"matomo_"` | Table prefix. |
| db.username | string | `"root"` | Database username. |
| extraConfigMaps | object | `{"create":false,"data":{}}` | Extra configMaps |
| extraSecrets | object | `{"create":false,"data":{}}` | Extra secrets |
| extraServices | object | `{}` | Extra services |
| extraVolumeMounts | list | `[]` | Extra volumes to mount |
| extraVolumes | list | `[]` | Extra volumes |
| global | object | `{"imagePullSecrets":[],"imageRegistry":""}` | Globals settings |
| global.imagePullSecrets | list | `[]` | Global image pull secrets |
| global.imageRegistry | string | `""` | Global image registry |
| matomo.automountServiceAccountToken | bool | `false` | Mount the service account token into Matomo pods. No workload in this chart uses the Kubernetes API; enable only if a custom sidecar needs it. |
| matomo.cli.enabled | bool | `true` | Enable the cli Deployment (runs supervisord for one-off `console` commands via `kubectl exec`). |
| matomo.cli.livenessProbe | object | `{}` | Liveness probe for the cli container (checks supervisord is running). |
| matomo.cli.readinessProbe | object | `{}` | Readiness probe for the cli container (checks supervisord is running). |
| matomo.cli.replicas | int | `1` | Number of replicas for the cli Deployment. |
| matomo.cli.resources | object | `{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Default resources for the Matomo cli container. |
| matomo.config | object | `{}` | Full install.json content, replacing the chart's built-in default when set. |
| matomo.cronJobs.coreArchive.activeDeadlineSeconds | int | `43200` | activeDeadlineSeconds for the core:archive Job. |
| matomo.cronJobs.coreArchive.command | string | `"./console core:archive --disable-scheduled-tasks"` | Command run by the core:archive CronJob. |
| matomo.cronJobs.coreArchive.concurrencyPolicy | string | `"Allow"` | concurrencyPolicy for the core:archive CronJob. |
| matomo.cronJobs.coreArchive.enabled | bool | `true` | Enable the core:archive CronJob. |
| matomo.cronJobs.coreArchive.labels | object | `{"component":"cronjob","instance":"matomo","managedBy":"helm","name":"matomo-jobs-corearchive","partOf":"matomo"}` | Labels applied to the coreArchive CronJob (name, instance, component, part-of, managed-by). |
| matomo.cronJobs.coreArchive.resources | object | `{"limits":{"cpu":"1000m","memory":"1Gi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Default resources for the core:archive cronjob. |
| matomo.cronJobs.coreArchive.schedule | string | `"*/60 * * * *"` | Cron schedule for core:archive. |
| matomo.cronJobs.scheduledTasks.activeDeadlineSeconds | int | `43200` | activeDeadlineSeconds for the scheduled-tasks Job. |
| matomo.cronJobs.scheduledTasks.command | string | `"./console scheduled-tasks:run"` | Command run by the scheduled-tasks CronJob. |
| matomo.cronJobs.scheduledTasks.enabled | bool | `true` | Enable the scheduled-tasks CronJob. |
| matomo.cronJobs.scheduledTasks.labels | object | `{"component":"cronjob","instance":"matomo","managedBy":"helm","name":"matomo-jobs-scheduled-tasks","partOf":"matomo"}` | Labels applied to the scheduledTasks CronJob (name, instance, component, part-of, managed-by). |
| matomo.cronJobs.scheduledTasks.php | string | `nil` | PHP configuration overrides for the scheduled-tasks CronJob. |
| matomo.cronJobs.scheduledTasks.resources | object | `{"limits":{"cpu":"1000m","memory":"1Gi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Default resources for the scheduled-tasks cronjob. |
| matomo.cronJobs.scheduledTasks.schedule | string | `"*/60 * * * *"` | Cron schedule for scheduled-tasks:run. |
| matomo.dashboard.enabled | bool | `true` | Enable the dashboard Deployment and Service. |
| matomo.dashboard.exporter | object | `{"enabled":true,"image":"","livenessProbe":{},"readinessProbe":{},"resources":{"limits":{"cpu":"100m","memory":"128Mi"},"requests":{"cpu":"15m","memory":"32Mi"}}}` | php-fpm_exporter (fpm-metrics) sidecar for the dashboard pod. |
| matomo.dashboard.exporter.enabled | bool | `true` | Enable the dashboard php-fpm_exporter (fpm-metrics) sidecar and its `metrics` port on the matomo-dashboard Service. |
| matomo.dashboard.exporter.image | string | `""` | Override the php-fpm_exporter image used for the dashboard (falls back to `matomo.exporterImage` when empty). |
| matomo.dashboard.exporter.livenessProbe | object | `{}` | Liveness probe for the dashboard php-fpm_exporter (fpm-metrics) container. |
| matomo.dashboard.exporter.readinessProbe | object | `{}` | Readiness probe for the dashboard php-fpm_exporter (fpm-metrics) container. |
| matomo.dashboard.exporter.resources | object | `{"limits":{"cpu":"100m","memory":"128Mi"},"requests":{"cpu":"15m","memory":"32Mi"}}` | Default resources for the dashboard php-fpm_exporter (fpm-metrics) container. |
| matomo.dashboard.firstuser | object | `{"email":"foo@example.com","password":"admin123","username":"admin"}` | Credentials for the first (super)user, applied by the init container on install. |
| matomo.dashboard.hostname | string | `"my.host"` | Hostname used for the dashboard Ingress/HTTPRoute rule. |
| matomo.dashboard.ingress.annotations | object | `{"digitalist.cloud/instance":"matomo"}` | Extra annotations for the dashboard Ingress. |
| matomo.dashboard.ingressClassName | string | `""` | ingressClassName for the dashboard Ingress. |
| matomo.dashboard.loadbalancer | bool | `false` | Create a LoadBalancer Service for the dashboard, used as the Ingress/HTTPRoute backend when true. |
| matomo.dashboard.nginx.conf | string | `""` | Override the full dashboard nginx configuration (nginx.conf, fastcgi_params, mime.types). As: conf:   nginx.conf: |     worker_processes 5;     load_module modules/ngx_http_geoip2_module.so;     ...   fastcgi_params: |     fastcgi_param   COUNTRY_CODE            $geoip2_data_country_code;     fastcgi_param   QUERY_STRING            $query_string;     fastcgi_param   REQUEST_METHOD          $request_method;     ...   mime.types: |     types {       text/html                                        html htm shtml;       text/css                                         css;       text/xml                                         xml;       ... |
| matomo.dashboard.nginx.image | string | `""` | Override the nginx image used for the dashboard (falls back to `nginx.image` when empty). |
| matomo.dashboard.nginx.livenessProbe | object | `{}` | Liveness probe for the dashboard nginx container. |
| matomo.dashboard.nginx.nginxWorkerProcesses | int | `5` | Worker process count for the dashboard nginx. |
| matomo.dashboard.nginx.readinessProbe | object | `{}` | Readiness probe for the dashboard nginx container. |
| matomo.dashboard.replicas | int | `1` | Number of replicas for the dashboard Deployment. |
| matomo.dashboard.secretName | string | `""` | Existing TLS secret name for the dashboard ingress. |
| matomo.dashboard.sidecars | list | `[]` | Extra containers to run alongside the dashboard pod. Added like this: sidecars: - name: fpm-metrics   image: hipages/php-fpm_exporter:2.2.0   imagePullPolicy: IfNotPresent   resources:     limits:       cpu: 500m       memory: 256Mi     requests:       cpu: 40m       memory: 32Mi |
| matomo.dashboard.tls | bool | `false` | Add a TLS block to the dashboard Ingress for `hostname`. |
| matomo.dashboard.whitelist | list | `[]` | List of CIDRs allowed to reach the dashboard Ingress (nginx.ingress.kubernetes.io/whitelist-source-range). Empty disables the restriction. |
| matomo.env | list | `[]` | Env variables to inject, if any. |
| matomo.exporterImage | string | `"hipages/php-fpm_exporter:2.2.0"` | Image for the php-fpm_exporter (fpm-metrics) sidecar shared by the dashboard and tracker pods. Override per-workload via `matomo.dashboard.exporter.image` / `matomo.tracker.exporter.image`. |
| matomo.extralabels | object | `{}` | Extra labels applied to Matomo pods (dashboard, tracker, cli, cronjobs, queuedtracking). |
| matomo.gatewayApi | object | `{"enabled":false,"extralabels":{},"parentRefs":[]}` | Gateway API support. When enabled, HTTPRoutes are created for the dashboard and tracker (using their `hostname` values) instead of - or alongside - the Ingress resources. Requires the Gateway API CRDs and a Gateway; TLS is terminated on the Gateway listener, not in the chart. |
| matomo.gatewayApi.extralabels | object | `{}` | Extra labels for the HTTPRoutes. |
| matomo.gatewayApi.parentRefs | list | `[]` | parentRefs applied to all HTTPRoutes, e.g.: parentRefs:   - name: my-gateway     namespace: my-namespace     sectionName: http |
| matomo.image | string | `"digitalist/matomo:5.12.0"` | Which image to use for Matomo deployment. |
| matomo.imagePullSecrets | list | `[]` | Image pull secrets for Matomo. |
| matomo.imageRegistry | string | `""` | Image registry to use. |
| matomo.ingress.annotations | object | `{}` | Extra annotations applied to both the dashboard and tracker Ingress resources. |
| matomo.ingress.enabled | bool | `true` | Create Ingress resources for the dashboard and tracker. |
| matomo.ingress.extralabels | object | `{}` | Extra labels for the dashboard and tracker Ingress resources. |
| matomo.initResources | object | `{"limits":{"cpu":"200m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Resources for the shared matomo-init init container (runs on every workload: dashboard, tracker, cli, cronjobs, queuedtracking, pre-upgrade and post-install Jobs). |
| matomo.installCommand | string | `"./console plugin:activate ExtraTools && ./console matomo:install --install-file=/tmp/matomo/install.json --force --do-not-drop-db"` | Install command. If already installed, it just creates the needed config. |
| matomo.license | string | `nil` | Reference to a secret holding a premium plugin license, if any. |
| matomo.livenessProbe | object | `{}` | Liveness probe for the Matomo php-fpm containers (dashboard, tracker). |
| matomo.php | string | `nil` | php.ini overrides for the dashboard and core:archive php-fpm containers. |
| matomo.phpfpm | string | `nil` | php-fpm pool tuning for the dashboard's php-fpm container. |
| matomo.postInstallCommand | string | `""` | Command to run in a post-install Job. The Job (and its resources) is only created when this is non-empty. |
| matomo.postInstallResources | object | `{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Default resources for the post-install Job container. |
| matomo.postInstallSleepTime | int | `5` | Seconds the post-install Job sleeps before running `postInstallCommand` (gives Matomo time to finish bootstrapping). |
| matomo.preUpgradeCommand | string | `""` | Command to run in a pre-upgrade Job. The Job (and its resources) is only created when this is non-empty. |
| matomo.preUpgradeResources | object | `{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Default resources for the pre-upgrade Job container. |
| matomo.preUpgradeSleepTime | int | `5` | Seconds the pre-upgrade Job sleeps before running `preUpgradeCommand`. |
| matomo.queuedTrackingMonitor.enabled | bool | `true` | Enable the queuedtracking:monitor Deployment. |
| matomo.queuedTrackingMonitor.livenessProbe | object | `{}` | Liveness probe for the queuedtracking-monitor container (checks supervisord is running). |
| matomo.queuedTrackingMonitor.readinessProbe | object | `{}` | Readiness probe for the queuedtracking-monitor container (checks supervisord is running). |
| matomo.queuedTrackingMonitor.replicas | int | `1` | Number of replicas for the queuedtracking-monitor Deployment. |
| matomo.queuedTrackingMonitor.resources | object | `{"limits":{"cpu":"500m","memory":"180Mi"},"requests":{"cpu":"300m","memory":"128Mi"}}` | Default resources for the queuedtracking-monitor container. |
| matomo.queuedTrackingProcess.enabled | bool | `false` | Enable the queuedtracking:process worker deployment. Required when QueuedTracking runs with processDuringTrackingRequest disabled. |
| matomo.queuedTrackingProcess.livenessProbe | object | `{}` | Liveness probe for the queuedtracking-process container (checks supervisord is running). Overriding replaces the default entirely. Example: livenessProbe:   exec:     command:     - /bin/sh     - -c     - "ps -A | grep supervisord"   initialDelaySeconds: 15   periodSeconds: 20 |
| matomo.queuedTrackingProcess.numProcs | int | `1` | Number of supervisord worker processes for queuedtracking:process per pod. |
| matomo.queuedTrackingProcess.readinessProbe | object | `{}` | Readiness probe for the queuedtracking-process container (checks supervisord is running). |
| matomo.queuedTrackingProcess.replicas | int | `1` | Number of replicas for the queuedtracking-process Deployment. |
| matomo.queuedTrackingProcess.resources | object | `{"limits":{"cpu":"1","memory":"220Mi"},"requests":{"cpu":"250m","memory":"128Mi"}}` | Default resources for the queuedtracking-process container. |
| matomo.readinessProbe | object | `{}` | Readiness probe for the Matomo php-fpm containers (dashboard, tracker). |
| matomo.resources | object | `{"limits":{"cpu":"2000m","memory":"4Gi"},"requests":{"cpu":"500m","memory":"512Mi"}}` | Default resources for the Matomo php-fpm container (dashboard). Sized for matomo.phpfpm's default pm.max_children (32): ~120Mi/worker realistic average plus headroom for the FPM master and occasional heavier requests. If you change pm.max_children, revisit this limit (and vice versa). |
| matomo.runAsUser | int | `82` | run container as user id. |
| matomo.tagManagerRegenerate.activeDeadlineSeconds | int | `300` | activeDeadlineSeconds for the regenerate-tagmanager Job. |
| matomo.tagManagerRegenerate.concurrencyPolicy | string | `"Forbid"` | concurrencyPolicy for the regenerate-tagmanager CronJob. |
| matomo.tagManagerRegenerate.enabled | bool | `false` | Enable the regenerate-tagmanager CronJob and the shared ReadWriteMany PersistentVolumeClaim mounted at /var/www/html/js on the dashboard and tracker pods. |
| matomo.tagManagerRegenerate.fsGroup | string | `nil` | fsGroup applied to the dashboard, tracker, and regenerate-tagmanager pods when this feature is enabled. nginx (nginx.runAsUser) and matomo (matomo.runAsUser) run as different UIDs but both need access to the shared PVC; fsGroup is pod-wide, unlike runAsUser, so it's what lets them actually share it. Defaults to matomo.runAsUser. Note this has no effect on hostPath-backed volumes (e.g. the kind e2e test fixture) - only on real volume plugins/CSI drivers (NFS, CephFS, etc). |
| matomo.tagManagerRegenerate.resources | object | `{"limits":{"cpu":"1000m","memory":"1Gi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Default resources for the regenerate-tagmanager CronJob container. |
| matomo.tagManagerRegenerate.schedule | string | `"*/2 * * * *"` | Cron schedule for the regenerate-tagmanager CronJob. |
| matomo.tagManagerRegenerate.seedResources | object | `{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"32Mi"}}` | Resources for the dashboard/tracker matomo-seed-tagmanager-js init container that seeds the shared volume on its first-ever mount. |
| matomo.tagManagerRegenerate.seedSourcePath | string | `"/usr/src/matomo/js"` | Path inside the matomo image the matomo-seed-tagmanager-js init container copies from when seeding the shared volume on its first-ever mount. Defaults to the default JS assets bundled in the image, alongside the rest of Matomo's source under /usr/src/matomo. |
| matomo.tagManagerRegenerate.volume.create | bool | `true` | Whether this chart creates the shared TagManager JS PersistentVolumeClaim (matomo-tagmanager-js). Set to false and provide existingClaim to use a PVC you've already created instead (e.g. one provisioned/managed outside this chart, or shared with other releases). storageClassName and size below only apply when this is true. |
| matomo.tagManagerRegenerate.volume.existingClaim | string | `""` | Name of a pre-existing PersistentVolumeClaim to use instead of the one this chart creates. Only used when create is false; must already exist in this release's namespace and support the ReadWriteMany access mode. |
| matomo.tagManagerRegenerate.volume.labels | object | `{}` | Extra labels for the tagmanager JS PersistentVolumeClaim. Labels set here will override or add to the default label (app: matomo-jobs-regenerate-tagmanager). |
| matomo.tagManagerRegenerate.volume.size | string | `"1Gi"` | Size of the shared TagManager JS PersistentVolumeClaim created by this chart (only used when create is true). |
| matomo.tagManagerRegenerate.volume.storageClassName | string | `""` | storageClassName for the shared TagManager JS PersistentVolumeClaim created by this chart (only used when create is true). Must support the ReadWriteMany access mode. Empty uses the cluster's default StorageClass (only suitable if that default supports RWX). |
| matomo.tracker.enabled | bool | `true` | Enable the tracker Deployment and Service. |
| matomo.tracker.exporter | object | `{"enabled":true,"image":"","livenessProbe":{},"readinessProbe":{},"resources":{"limits":{"cpu":"40m","memory":"32Mi"},"requests":{"cpu":"40m","memory":"32Mi"}}}` | php-fpm_exporter (fpm-metrics) sidecar for the tracker pod. |
| matomo.tracker.exporter.enabled | bool | `true` | Enable the tracker php-fpm_exporter (fpm-metrics) sidecar and its `metrics` port on the matomo-tracker Service. |
| matomo.tracker.exporter.image | string | `""` | Override the php-fpm_exporter image used for the tracker (falls back to `matomo.exporterImage` when empty). |
| matomo.tracker.exporter.livenessProbe | object | `{}` | Liveness probe for the tracker php-fpm_exporter (fpm-metrics) container. |
| matomo.tracker.exporter.readinessProbe | object | `{}` | Readiness probe for the tracker php-fpm_exporter (fpm-metrics) container. |
| matomo.tracker.exporter.resources | object | `{"limits":{"cpu":"40m","memory":"32Mi"},"requests":{"cpu":"40m","memory":"32Mi"}}` | Default resources for the tracker php-fpm_exporter (fpm-metrics) container. |
| matomo.tracker.hostname | string | `"tracker.my.host"` | Hostname used for the tracker Ingress/HTTPRoute rule. |
| matomo.tracker.ingress.annotations | object | `{"digitalist.cloud/instance":"matomo"}` | Extra annotations for the tracker Ingress. |
| matomo.tracker.ingressClassName | string | `""` | ingressClassName for the tracker Ingress. |
| matomo.tracker.loadbalancer | bool | `false` | Create a LoadBalancer Service for the tracker, used as the Ingress/HTTPRoute backend when true. |
| matomo.tracker.nginx.livenessProbe | object | `{}` | Liveness probe for the tracker nginx container. |
| matomo.tracker.nginx.nginxWorkerProcesses | int | `5` | Worker process count for the tracker nginx. |
| matomo.tracker.nginx.readinessProbe | object | `{}` | Readiness probe for the tracker nginx container. |
| matomo.tracker.nginx.resources | object | `{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}` | Default resources for the tracker nginx container. |
| matomo.tracker.phpfpm | object | `{"max_children":75,"max_requests":500,"max_spare_servers":75,"memory_limit":"2048M","min_spare_servers":5,"process_idle_timeout":"600s","start_servers":5,"status_path":"/status","type":"ondemand"}` | php-fpm pool tuning for the tracker (process manager type, max/spare children, idle timeout, max requests, status path). |
| matomo.tracker.replicas | int | `1` | Number of replicas for the tracker Deployment. |
| matomo.tracker.resources | object | `{"limits":{"cpu":"1000m","memory":"768Mi"},"requests":{"cpu":"300m","memory":"256Mi"}}` | Default resources for the Matomo php-fpm container in the tracker. |
| matomo.tracker.secretName | string | `""` | Existing TLS secret name for the tracker ingress. |
| matomo.tracker.tls | bool | `false` | Add a TLS block to the tracker Ingress for `hostname`. |
| matomo.waitForDbResources | object | `{"limits":{"cpu":"100m","memory":"64Mi"},"requests":{"cpu":"10m","memory":"16Mi"}}` | Resources for the wait-for-db init container (pre-upgrade and post-install Jobs only). |
| matomo.warmupCommand | string | `"./console core:update --yes --no-interaction"` | force` (in installCommand above) doesn't itself fire the plugin install/update events some plugins (e.g. TagManager) hook to regenerate generated assets - normally left to happen lazily on the first web request(s) after a (re)start. Since static-data is an emptyDir, that bookkeeping resets on every fresh pod, so without this, concurrent probes/traffic on every restart each independently race to redo that (expensive) regeneration. Running it once here, synchronously, avoids that. Unless matomo.tagManagerRegenerate.enabled is true, this is also followed by a guarded `tagmanager:regenerate-released-containers` call (see matomo.tagManagerRegenerateGuarded in _helpers.tpl); when that feature is enabled, the regenerate-tagmanager CronJob owns that work instead, so it's skipped here. |
| matomo.warmupResources | object | `{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Resources for the matomo-warmup init container (dashboard and tracker). |
| namespace | string | `"matomo"` | Namespace to install Matomo in, default matomo. |
| networkPolicy | object | `{"enabled":true,"ingress":[{}]}` | NetworkPolicy for the Matomo workloads. When enabled, one NetworkPolicy per component (dashboard, tracker, cli, queuedtracking monitor/process) is created. The default rule allows all ingress, which changes nothing functionally but makes every pod covered by a policy; tighten by overriding `networkPolicy.ingress` for your environment. |
| networkPolicy.ingress | list | `[{}]` | Ingress rules applied to every component policy. Default: allow all. |
| nginx | object | `{"image":"digitalist/nginx:1.21.6","imagePullSecrets":[],"resources":{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"64Mi"}},"runAsUser":100}` | Default nginx image and settings shared by the dashboard (unless `matomo.dashboard.nginx.image` is set) and the tracker. |
| nginx.image | string | `"digitalist/nginx:1.21.6"` | nginx image used for the dashboard and tracker. |
| nginx.imagePullSecrets | list | `[]` | Image pull secrets for the nginx image. |
| nginx.resources | object | `{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}` | Default resources for the dashboard nginx container. |
| nginx.runAsUser | int | `100` | run the nginx container as this user id. |
| nodeSelector | object | `{}` | Node labels for pod assignment. |
| tolerations | list | `[]` | Tolerations for pod assignment |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
