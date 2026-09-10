{
  _config+:: {
    selector: '',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'argocd-sync-state',
        rules: [
          // Removed WhiteListedApplicationOutOfSync/CronSyncFailed: redundant with
          // ArgoCdAppOutOfSync below, expr and summary didn't match (waiting/failed
          // vs "out of sync"), the whitelisted="true" label doesn't exist on this
          // cluster's metrics, and neither ever fired a single notification in Gitea.
          // Inspiration from here https://github.com/adinhodovic/argo-cd-mixin/blob/main/alerts/alerts.libsonnet
          {
            alert: 'ArgoCdAppOutOfSync',
            expr: 'count by (project, sync_status) ((sum by (name, job, dest_server, project, sync_status) (argocd_app_info{job=~".*",sync_status!="Synced"}) >= 1) + on (name, project) group_left kubeaidManagedApps)',
            labels: {
              severity: 'warning',
            },
            'for': '2h',
            annotations: {
              summary: 'ArgoCD Application is Out Of Sync.',
              description: |||
                The following applications under project '{{ .Labels.project }}' are out of sync (status: {{ .Labels.sync_status }}):
                {{- range query (printf "sum by (name, project) (argocd_app_info{project='%s', sync_status='%s'}) and on(name, project) kubeaidManagedApps" .Labels.project .Labels.sync_status) }}
                - {{ .Labels.name }}
                {{- end }}
              |||,
            },
          },
          {
            alert: 'ArgoCdAppUnhealthy',
            expr: 'count by (health_status,project) ((sum by (name, job, dest_server, project, health_status) (argocd_app_info{health_status!~"Healthy|Progressing"}) >= 1) + on (name, project) group_left kubeaidManagedApps)',
            labels: {
              severity: 'warning',
            },
            'for': '2h',
            annotations: {
              summary: 'ArgoCD Application is not healthy.',
              description: |||
                The following applications under project '{{ .Labels.project }}' are not healthy (status: {{ .Labels.health_status }}):
                {{- range query (printf "sum by (name, project) (argocd_app_info{project='%s', health_status='%s'}) and on(name, project) kubeaidManagedApps" .Labels.project .Labels.health_status) }}
                - {{ .Labels.name }}
                {{- end }}
              |||,
            },
          },
        ],
      },
    ],
  },
}
