local defaults = {
  local defaults = self,
  name: 'perses-operator',
  namespace: 'perses-dev',
  version: error 'must provide version',
  image: 'persesdev/perses-operator:' + defaults.version,
  resources: {
    limits: { cpu: '500m', memory: '128Mi' },
    requests: { cpu: '10m', memory: '64Mi' },
  },
  commonLabels:: {
    'app.kubernetes.io/name': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'controller',
    'app.kubernetes.io/created-by': 'perses-operator',
    'app.kubernetes.io/part-of': 'perses-operator',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
};

function(params) {
  local po = self,
  config:: defaults + params,

  // Prefixing with 0 to ensure these manifests are listed and therefore created first.
  '0persesCustomResourceDefinition': import 'generated/perses.dev_perses-crd.json',
  '0persesdashboardsCustomResourceDefinition': import 'generated/perses.dev_persesdashboards-crd.json',
  '0persesdatasourcesCustomResourceDefinition': import 'generated/perses.dev_persesdatasources-crd.json',
  '0persesglobaldatasourcesCustomResourceDefinition': import 'generated/perses.dev_persesglobaldatasources-crd.json',

  local deployment_gen = import 'generated/manager.json',
  local service_account_gen = import 'generated/service_account.json',
  local perses_editor_role_gen = import 'generated/perses_editor_role.json',
  local perses_viewer_role_gen = import 'generated/perses_viewer_role.json',
  local persesdashboard_viewer_role_gen = import 'generated/persesdashboard_viewer_role.json',
  local persesdashboard_editor_role_gen = import 'generated/persesdashboard_editor_role.json',
  local persesdatasource_viewer_role_gen = import 'generated/persesdatasource_viewer_role.json',
  local persesdatasource_editor_role_gen = import 'generated/persesdatasource_editor_role.json',
  local persesglobaldatasource_viewer_role_gen = import 'generated/persesglobaldatasource_viewer_role.json',
  local persesglobaldatasource_editor_role_gen = import 'generated/persesglobaldatasource_editor_role.json',
  local leader_election_role_gen = import 'generated/leader_election_role.json',
  local leader_election_role_binding_gen = import 'generated/leader_election_role_binding.json',
  local role_binding_gen = import 'generated/role_binding.json',
  local role_gen = import 'generated/role.json',
  local service_monitor_gen = import 'generated/monitor.json',

  deployment: deployment_gen {
    metadata+: {
      name: po.config.name,
      namespace: po.config.namespace,
      labels: po.config.commonLabels,
    },
    spec+: {
      selector: { matchLabels: po.config.selectorLabels },
      template+: {
        metadata+: {
          labels: po.config.commonLabels,
        },
        spec+: {
          containers: [
            deployment_gen.spec.template.spec.containers[0] {
              image: po.config.image,
              resources: po.config.resources,
            },
          ],
          serviceAccountName: po.config.name,
        },
      },
    },
  },

  serviceAccount: service_account_gen {
    metadata+: {
      name: po.config.name,
      namespace: po.config.namespace,
      labels: po.config.commonLabels,
    },
  },

  persesEditorRole: perses_editor_role_gen {
    metadata+: {
      name: 'perses-editor-role',
      labels: po.config.commonLabels {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/instance': 'perses-editor-role',
      },
    },
  },

  persesViewerRole: perses_viewer_role_gen {
    metadata+: {
      name: 'perses-viewer-role',
      labels: po.config.commonLabels {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/instance': 'perses-viewer-role',
      },
    },
  },

  persesDashboardEditorRole: persesdashboard_editor_role_gen {
    metadata+: {
      name: 'persesdashboard-editor-role',
      labels: po.config.commonLabels {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/instance': 'persesdashboard-editor-role',
      },
    },
  },

  persesDashboardViewerRole: persesdashboard_viewer_role_gen {
    metadata+: {
      name: 'persesdashboard-viewer-role',
      labels: po.config.commonLabels {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/instance': 'persesdashboard-viewer-role',
      },
    },
  },

  persesDatasourceEditorRole: persesdatasource_editor_role_gen {
    metadata+: {
      name: 'persesdatasource-editor-role',
      labels: po.config.commonLabels {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/instance': 'persesdatasource-editor-role',
      },
    },
  },

  persesDatasourceViewerRole: persesdatasource_viewer_role_gen {
    metadata+: {
      name: 'persesdatasource-viewer-role',
      labels: po.config.commonLabels {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/instance': 'persesdatasource-viewer-role',
      },
    },
  },

  persesGlobalDatasourceEditorRole: persesglobaldatasource_editor_role_gen {
    metadata+: {
      name: 'persesglobaldatasource-editor-role',
      labels: po.config.commonLabels {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/instance': 'persesglobaldatasource-editor-role',
      },
    },
  },

  persesGlobalDatasourceViewerRole: persesglobaldatasource_viewer_role_gen {
    metadata+: {
      name: 'persesglobaldatasource-viewer-role',
      labels: po.config.commonLabels {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/instance': 'persesglobaldatasource-viewer-role',
      },
    },
  },

  roleBinding: role_binding_gen {
    metadata+: {
      name: po.config.name,
      namespace: po.config.namespace,
      labels: po.config.commonLabels,
    },
    roleRef+: {
      name: po.config.name,
    },
    subjects: [
      role_binding_gen.subjects[0] {
        name: po.config.name,
        namespace: po.config.namespace,
      },
    ],
  },

  role: role_gen {
    metadata+: {
      name: po.config.name,
      labels: po.config.commonLabels {
        'app.kubernetes.io/component': 'rbac',
      },
    },
  },

  leaderElectionRole: leader_election_role_gen {
    metadata+: {
      name: po.config.name + '-leader-election-role',
      labels: po.config.commonLabels {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/instance': 'leader-election-role',
      },
      namespace: po.config.namespace,
    },
  },

  leaderElectionRoleBinding: leader_election_role_binding_gen {
    metadata+: {
      name: po.config.name + '-leader-election-rolebinding',
      labels: po.config.commonLabels {
        'app.kubernetes.io/component': 'rbac',
        'app.kubernetes.io/instance': 'leader-election-rolebinding',
      },
      namespace: po.config.namespace,
    },
    roleRef+: {
      name: po.config.name + '-leader-election-role',
    },
    subjects: [
      leader_election_role_binding_gen.subjects[0] {
        name: po.config.name,
        namespace: po.config.namespace,
      },
    ],
  },

  serviceMonitor: service_monitor_gen {
    metadata+: {
      name: po.config.name,
      labels: po.config.commonLabels,
      namespace: po.config.namespace,
    },
    spec+: {
      selector: {
        matchLabels: po.config.selectorLabels,
      },
    },
  },

  local mixin = (import 'mixin/mixin.libsonnet') {
    _config+:: {
      persesOperatorSelector: 'job="%s"' % po.config.name,
    },
  },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: po.config.name,
      namespace: po.config.namespace,
      labels: po.config.commonLabels,
    },
    spec: mixin.prometheusAlerts,
  },
}
