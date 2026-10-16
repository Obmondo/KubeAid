# Stale and Helm Update Error Report

Generated locally via `bin/manage-helm-chart.sh --update-all` on 2026-08-21.

## Stale Charts (chart version unchanged for 90+ days, image may be outdated) - 28

|Chart|Version|Days stale|Last bumped|By|
|---|---|---|---|---|
|calcom|0.8.6|133|2026-04-09|Onkar|
|castopod|1.12.10|218|2026-01-14|aman|
|aws-cloud-controller-manager|0.0.11|133|2026-04-09|Ashish Jaiswal|
|cloud-provider-azure|1.36.0|94|2026-05-18|Hritik Batra|
|circleci-runner|0.1.0|1637|2022-02-25|Ashish Jaiswal|
|dokuwiki|16.2.11|743|2024-08-07|Hritik Batra|
|external-dns|1.21.1|107|2026-05-05|Hritik Batra|
|filebeat|8.5.1|1293|2023-02-04|EnableIT Bot|
|friendica|1.0.0|217|2026-01-15|Shivam|
|grafana-operator|v5.20.0|257|2025-12-06|Ashish Jaiswal|
|ingress-nginx|4.15.1|150|2026-03-23|Hritik Batra|
|k8s-event-logger|1.1.8|675|2024-10-14|Hritik Batra|
|loki-stack|2.10.3|257|2025-12-06|Ashish Jaiswal|
|matomo|11.0.0|257|2025-12-06|Ashish Jaiswal|
|mattermost-operator|1.0.5|127|2026-04-15|Ashish Jaiswal|
|metallb|6.4.22|358|2025-08-27|Hritik Batra|
|minio|5.4.0|329|2025-09-26|Divyam  Azad|
|netbird|1.9.0|358|2025-08-27|Sidharth Jawale|
|oncall|1.16.5|358|2025-08-27|Hritik Batra|
|opensearch-operator|3.0.2|133|2026-04-09|Ashish Jaiswal|
|prometheus-adapter|5.3.0|177|2026-02-24|Hritik Batra|
|rabbitmq-cluster-operator|4.4.34|358|2025-08-27|Hritik Batra|
|redmine|34.0.0|358|2025-08-27|Hritik Batra|
|sftpgo|0.40.0|366|2025-08-19|Sanskar Bhushan|
|step-certificates|1.30.1|133|2026-04-09|Ashish Jaiswal|
|autocert|1.20.7|133|2026-04-09|Ashish Jaiswal|
|traefik-forward-auth|0.3.10|989|2023-12-05|nihaldivyam|
|whoami|6.0.0|372|2025-08-13|Hritik Batra|

## Helm Update Errors (update failed, left on previous version) - 7

- gitea: failed to add Helm repository https://dl.gitea.com/charts/
- kube2iam: helm dependency update failed while bumping 2.6.0 -> not found in repo
- security-exporter: failed to add Helm repository null
- backup-exporter: failed to add Helm repository null
- coturn: failed to add Helm repository https://small-hack.github.io/coturn-chart/
- rook-ceph: helm dependency update failed while bumping v1.20.4 -> v1.20.5
- sealed-secrets: failed to add Helm repository https://bitnami-labs.github.io/sealed-secrets
