local addMixin = import 'lib/addmixin.libsonnet';
local utils = import 'lib/utils.libsonnet';

local remove_nulls = (
  function(arr)
    std.filter((function(o) o != null), arr)
);

local ext_vars = std.extVar('vars');

local default_vars = {
  prometheus_scrape_namespaces+: [],

  // Custom kubeaid or non kubeaid apps that need AutoSync
  kubeaid_users_apps+: [],
  kubeaid_apps+: [
    'argo-cd',
    'argocd-image-updater',
    'aws-ebs-csi-driver',
    'aws-efs-csi-driver',
    'capi-cluster',
    'ccm-hetzner',
    'cerebro',
    'cert-manager',
    'cilium',
    'circleci-runner',
    'cloudnative-pg',
    'cluster-api',
    'cluster-autoscaler',
    'crossplane',
    'dokuwiki',
    'errbot',
    'external-dns',
    'filebeat',
    'fluent-bit',
    'gatekeeper',
    'gitea-runner',
    'gitlab-runner',
    'grafana-operator',
    'graylog',
    'haproxy',
    'harbor',
    'kubeaid-custom-azure',
    'k8s-event-logger',
    'keda',
    'keycloakx',
    'kube2iam',
    'kubernetes-dashboard',
    'mail',
    'mariadb-operator',
    'matomo',
    'mattermost-team-edition',
    'metallb',
    'metrics-server',
    'mongodb-operator',
    'obmondo-k8s-agent',
    'oncall',
    'opencost',
    'opensearch',
    'opensearch-dashboards',
    'postgres-operator',
    'prometheus-adapter',
    'prometheus-linuxaid',
    'puppetserver',
    'rabbitmq-operator',
    'redis-operator',
    'relate',
    'reloader',
    'rook-ceph',
    'sealed-secrets',
    'snapshot-controller',
    'sonarqube',
    'strimzi-kafka-operator',
    'teleport-cluster',
    'teleport-kube-agent',
    'tigera-operator',
    'traefik',
    'traefik-forward-auth',
    'traefik-forward-auth-rbac',
    'velero',
    'whoami',
    'zfs-localpv',
    'smartmon',
    'mdraid',
  ],
  prometheus_operator_resources: {
    limits: { memory: '80Mi' },
    requests: { cpu: '20m', memory: '80Mi' },
  },
  prometheus_operator_kubeRbacProxy_resources: {
    limits: { memory: '40Mi' },
    requests: { cpu: '1m', memory: '40Mi' },
  },
  prometheus_operator_configReloaderResources: {
    limits: { cpu: '0', memory: '' },
    resources: { cpu: '', memory: '' },
  },
  alertmanager_resources: {
    limits: { memory: '50Mi' },
    requests: { cpu: '1m', memory: '50Mi' },
  },
  prometheus_resources: {
    limits: { memory: '3Gi' },
    requests: { cpu: '200m', memory: '2500Mi' },
  },
  prometheus_adapter_resources: {
    limits: { memory: '2Gi' },
    requests: { cpu: '200m', memory: '1500Mi' },
  },
  prometheus_adapter_additional_rules: [],
  grafana_resources: {
    limits: { memory: '200Mi' },
    requests: { cpu: '6m', memory: '100Mi' },
  },
  node_exporter_resources: {
    limits: { memory: '180Mi' },
    requests: { cpu: '3m', memory: '180Mi' },
  },
  node_exporter_kubeRbacProxyMain_resources: {
    limits: { memory: '40Mi' },
    requests: { cpu: '1m', memory: '40Mi' },
  },
  kube_state_metrics_kubeRbacProxyMain_resources: {
    limits: { memory: '40Mi' },
    requests: { cpu: '1m', memory: '40Mi' },
  },
  kube_state_metrics_kubeRbacProxySelf_resources: {
    limits: { memory: '40Mi' },
    requests: { cpu: '1m', memory: '40Mi' },
  },

  grafana_keycloak_enable: false,
  grafana_keycloak_url: '',
  grafana_keycloak_realm: '',
  grafana_keycloak_client_id: 'grafana',
  grafana_keycloak_secretref: {
    name: 'kube-prometheus-stack-grafana',
    key: 'grafana-keycloak-secret',
  },
  prometheus: {
    storage: {
      size: '30Gi',
    },
    retention: '30d',
  },
  grafana_ingress_annotations: {
    'cert-manager.io/cluster-issuer': 'letsencrypt',
  },
  prometheus_ingress_annotations: {
    'cert-manager.io/cluster-issuer': 'letsencrypt',
  },
  alertmanager_ingress_annotations: {
    'cert-manager.io/cluster-issuer': 'letsencrypt',
  },
  addMixins: {
    ceph: false,
    'argo-cd': true,
    'node-pressure': true,
    sealedsecrets: true,
    etcd: true,
    velero: false,
    zfs: false,
    opensearch: false,
    'cert-manager': true,
    'kubernetes-version-info': true,
    // Enable this when we move metrics generation into obmondo-k8s-agent
    // gitea/EnableIT/internal/issues/21
    'node-count-monthly-status': false,
    'argo-cd-sync-state': true,
    rabbitmq: false,
    'monitor-prometheus-stack': false,
    smartmon: false,
    mdraid: true,
    opencost: false,
    'kubelet-cert-expiry': false,
  },
  mixin_configs: {
    // Example:
    //
    // velero+: {
    //   selector: 'schedule=~"^ops.+"',
    // },
  },
  connect_keda: false,
  grafana_plugins+: [],
  grafana_dashboards+: {},
};

local vars = default_vars + ext_vars;

local mixins = remove_nulls([
  addMixin(
    'ceph',
    (import 'github.com/ceph/ceph/monitoring/ceph-mixin/mixin.libsonnet'),
    vars,
  ),
  addMixin(
    'sealedsecrets',
    (import 'github.com/bitnami-labs/sealed-secrets/contrib/prometheus-mixin/mixin.libsonnet'),
    vars,
  ),
  addMixin(
    'etcd',
    (import 'github.com/etcd-io/etcd/contrib/mixin/mixin.libsonnet'),
    vars,
  ),
  addMixin(
    'velero',
    (import 'mixins/velero/mixin.libsonnet'),
    vars,
  ),
  addMixin(
    'kubernetes-version-info',
    (import 'mixins/kube-version/mixin.libsonnet'),
    vars,
  ),
  addMixin(
    'node-count-monthly-status',
    (import 'mixins/node-count/mixin.libsonnet'),
    vars,
  ),
  addMixin(
    'cert-manager',
    (import 'gitlab.com/uneeq-oss/cert-manager-mixin/mixin.libsonnet'),
    vars,
  ),
  addMixin(
    'argo-cd',
    (import 'mixins/argo-cd/mixin.libsonnet'),
    vars,
  ),
  (
    if std.objectHas(vars, 'kube_prometheus_version') && std.member(['v0.13.0', 'v0.14.0'], vars.kube_prometheus_version) then
      addMixin(
        'node-pressure',
        (import 'mixins/node-pressure/mixin.libsonnet'),
        vars,
      )
  ),
  addMixin(
    'opensearch',
    (import 'github.com/grafana/jsonnet-libs/opensearch-mixin/mixin.libsonnet'),
    vars,
  ),
  (
    if std.objectHas(vars, 'kube_prometheus_version') && vars.kube_prometheus_version == 'v0.13.0' then (
      addMixin(
        'rabbitmq',
        (import 'github.com/adinhodovic/rabbitmq-mixin/mixin.libsonnet'),
        vars,
      )
    ) else (
      addMixin(
        'rabbitmq',
        (import 'github.com/grafana/jsonnet-libs/rabbitmq-mixin/mixin.libsonnet'),
        vars,
      )
    )
  ),
  addMixin(
    'smartmon',
    (import 'mixins/smartmon/mixin.libsonnet'),
    vars,
  ),
  addMixin(
    'zfs',
    (import 'mixins/zfs/mixin.libsonnet'),
    vars,
  ),
  addMixin(
    'mdraid',
    (import 'mixins/mdraid/mixin.libsonnet'),
    vars,
  ),
  addMixin(
    'opencost',
    (import 'github.com/adinhodovic/opencost-mixin/mixin.libsonnet'),
    vars,
  ),
  addMixin(
    'kubelet-cert-expiry',
    (import 'mixins/kubelet-cert-expiry/mixin.libsonnet'),
    vars,
  ),
]);

local scrape_namespaces = std.uniq(std.sort(std.flattenArrays(
  [
    vars.prometheus_scrape_namespaces,
  ] + [
    ['argocd'],
    ['sealed-secrets'],
    ['cert-manager'],
    ['traefik'],
    ['monitoring'],
  ] + (
    if std.objectHas(vars, 'connect_obmondo') && vars.connect_obmondo then
      [
        ['obmondo'],
      ]
    else []
  )
)));

local relabelings = import 'kube-prometheus/addons/dropping-deprecated-metrics-relabelings.libsonnet';

local kp =
  (import 'kube-prometheus/main.libsonnet') +
  // Uncomment the following imports to enable its patches
  // (import 'kube-prometheus/addons/anti-affinity.libsonnet') +
  // (import 'kube-prometheus/addons/managed-cluster.libsonnet') +
  // (import 'kube-prometheus/addons/node-ports.libsonnet') +
  // (import 'kube-prometheus/addons/static-etcd.libsonnet') +
  // (import 'kube-prometheus/addons/external-metrics.libsonnet') +
  // NOTE: we need this condition because custom-metrics.libsonnet is broken prior to v0.13.0
  (
    if std.objectHas(vars, 'enable_custom_metrics_apiservice') && vars.enable_custom_metrics_apiservice then (
      import 'kube-prometheus/addons/custom-metrics.libsonnet'
    ) else {}
  ) +
  {
    argocdApplications+: {
      prometheusRuleExample+: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'PrometheusRule',
        metadata: {
          name: 'kubeaid-managed-apps',
          namespace: $.values.common.namespace,
        },
        spec: {
          groups: [
            {
              name: 'kubeaidManagedApps',
              rules: [
                {
                  record: 'kubeaidManagedApps',
                  expr: 0,
                  labels: {
                    name: argocdApps,
                    // TODO: maybe add support for other projects
                    project: 'kubeaid',
                  },
                }
                for argocdApps in vars.kubeaid_apps + vars.kubeaid_users_apps
              ],
            },
          ],
        },
      },
    },
  } +
  {
    grafana+: {
      networkPolicy+: {
        spec+: {
          ingress+: [{
            from: [{
              podSelector: {
                matchLabels: {
                  'app.kubernetes.io/name': 'traefik',
                },
              },
              namespaceSelector: {
                matchLabels: {
                  'kubernetes.io/metadata.name': 'traefik',
                },
              },
            }],
            ports: [{
              port: 'http',
              protocol: 'TCP',
            }],
          }],
        },
      },
    },
  } +
  {
    prometheus+: {
      prometheus+: {
        spec+: {
          externalUrl: if std.objectHas(vars, 'prometheus_ingress_host') then (
            'https://' + vars.prometheus_ingress_host
          ) else '',
          replicas: if std.objectHas(vars.prometheus, 'replicas') then vars.prometheus.replicas else 1,
          resources: vars.prometheus_resources,
          retention: vars.prometheus.retention,
          storage: {
            volumeClaimTemplate: {
              apiVersion: 'v1',
              kind: 'PersistentVolumeClaim',
              spec: {
                accessModes: ['ReadWriteOnce'],
                resources: { requests: { storage: vars.prometheus.storage.size } },
              } + if std.objectHas(vars.prometheus.storage, 'classname') then (
                { storageClassName: vars.prometheus.storage.classname }
              ) else {},
            },
          },
          ruleNamespaceSelector+: {
            matchExpressions:
              [{
                key: 'kubernetes.io/metadata.name',
                operator: 'In',
                values: scrape_namespaces,
              }],
          },
        } + if std.objectHas(vars.prometheus, 'remoteWrite') then (
          {
            remoteWrite+: [
              {
                url: remoteWrite.url,
                queueConfig: {
                  maxSamplesPerSend: 10000,
                },
                basicAuth: {
                  username: {
                    name: remoteWrite.basicAuth.secret,
                    // Field for username in secret
                    key: 'username',
                  },
                  password: {
                    name: remoteWrite.basicAuth.secret,
                    // Field for password in secret
                    key: 'password',
                  },
                },
              }
              for remoteWrite in vars.prometheus.remoteWrite
            ],
          }
        ) else {},
      },
      networkPolicy+: {
        spec+: {
          ingress+: [
            {
              from: [{
                podSelector: {
                  matchLabels: {
                    'app.kubernetes.io/name': 'prometheus-adapter',
                  },
                },
              }],
              ports: [{
                port: 9090,
                protocol: 'TCP',
              }],
            },
            {
              from: [{
                namespaceSelector: {
                  matchLabels: {
                    'kubernetes.io/metadata.name': 'mattermost',
                  },
                },
                podSelector: {
                  matchLabels: {
                    'kubeaid.io/permissions': 'allow-prometheus',
                  },
                },
              }],
              ports: [{
                port: 9090,
                protocol: 'TCP',
              }],
            },
            {
              from: [{
                namespaceSelector: {
                  matchLabels: {
                    'kubernetes.io/metadata.name': 'traefik',
                  },
                },
                podSelector: {
                  matchLabels: {
                    'app.kubernetes.io/name': 'traefik',
                  },
                },
              }],
              ports: [{
                port: 9090,
                protocol: 'TCP',
              }],
            },
            {
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      'kubernetes.io/metadata.name': 'obmondo',
                    },
                  },
                  podSelector: {
                    matchLabels: {
                      'app.kubernetes.io/name': 'obmondo-k8s-agent',
                    },
                  },
                },
              ],
              ports: [{
                port: 9090,
                protocol: 'TCP',
              }],
            },
            {
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      'kubernetes.io/metadata.name': 'opencost',
                    },
                  },
                  podSelector: {
                    matchLabels: {
                      'app.kubernetes.io/name': 'opencost',
                    },
                  },
                },
              ],
              ports: [{
                port: 9090,
                protocol: 'TCP',
              }],
            },
          ] + (
            if vars.connect_keda then [{
              from: [
                {
                  podSelector: {
                    matchLabels: {
                      'app.kubernetes.io/part-of': 'keda-operator',
                    },
                  },
                },
              ],
              ports: [{
                port: 9090,
                protocol: 'TCP',
              }],
            }] else []
          ),
        },
      },
    },
  } + (
    if vars.platform == 'kubeadm' then {
      kubernetesControlPlane+: {
        serviceMonitorKubeScheduler+: {
          spec+: {
            endpoints: [{
              port: 'https-metrics',
              interval: '30s',
              scheme: 'https',
              bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
              tlsConfig: { insecureSkipVerify: true },
            }],
          },
        },
        serviceMonitorKubeControllerManager+: {
          spec+: {
            endpoints: [{
              port: 'https-metrics',
              interval: '30s',
              scheme: 'https',
              bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
              tlsConfig: {
                insecureSkipVerify: true,
              },
              metricRelabelings: relabelings + [
                {
                  sourceLabels: ['__name__'],
                  regex: 'etcd_(debugging|disk|request|server).*',
                  action: 'drop',
                },
              ],
            }],
            selector: {
              matchLabels: { 'app.kubernetes.io/name': 'kube-controller-manager' },
            },
            namespaceSelector: {
              matchNames: ['kube-system'],
            },
          },
        },
      },
    } else {}
  ) +
  {
    values+:: {
      common+: {
        platform: vars.platform,
        namespace: 'monitoring',
      },

      prometheus+: {
        // [ i for i in scrape_namespaces if std.get(defaults.mixins, i) == true ],
        namespaces+: scrape_namespaces,
      },

      prometheusOperator+: {
        resources: vars.prometheus_operator_resources,
        configReloaderResources+: vars.prometheus_operator_configReloaderResources,
        kubeRbacProxy+: {
          resources+: vars.prometheus_operator_kubeRbacProxy_resources,
        },
      },
      prometheusAdapter+: {
        resources: vars.prometheus_adapter_resources,
        config+:: {
          rules+: vars.prometheus_adapter_additional_rules,
        },
      },
      // This is ONLY supported in release-0.11+ and main
      kubeStateMetrics+: {
        kubeRbacProxyMain+: {
          resources+: vars.kube_state_metrics_kubeRbacProxyMain_resources,
        },
        kubeRbacProxySelf+: {
          resources+: vars.kube_state_metrics_kubeRbacProxySelf_resources,
        },
      },

      nodeExporter+: {
        resources: vars.node_exporter_resources,
        kubeRbacProxy+: {
          resources+: vars.node_exporter_kubeRbacProxyMain_resources,
        },
      },

      grafana+: {
        plugins: vars.grafana_plugins,
        resources: vars.grafana_resources,
        dashboards+: {
          [mixin.name + '-' + dashboard]: mixin.grafanaDashboards[dashboard]
          for mixin in mixins
          if mixin.grafanaDashboards != null
          for dashboard in std.objectFields(mixin.grafanaDashboards)
        },
        folderDashboards+:: vars.grafana_dashboards,
        analytics+: {
          check_for_updates: false,
        },
        env: if vars.grafana_keycloak_enable then [
          {
            name: 'GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION',
            value: 'true',
          },
          {
            name: 'GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET',
            valueFrom+: {
              secretKeyRef+: {
                name: vars.grafana_keycloak_secretref.name,
                key: vars.grafana_keycloak_secretref.key,
              },
            },
          },
        ] else [],
        config+: {
          sections: {
            date_formats: { default_timezone: 'UTC' },
            auth: {
              disable_login_form: false,
              // oauth_auto_login: true,
              disable_signout_menu: false,
            } + (
              if vars.grafana_keycloak_enable then {
                // NOTE: currently it ask user to logout from keycloak, would be nice to logout directly
                // when we click on logout in grafana console. we will improve on this later
                signout_redirect_url: vars.grafana_keycloak_url + '/auth/realms/' + vars.grafana_keycloak_realm + '/protocol/openid-connect/logout?post_logout_redirect_uri=' + vars.grafana_root_url + '/login&client_id=' + vars.grafana_keycloak_client_id,
              } else {}
            ),
            analytics: {
              check_for_updates: false,
            },
            server: {
              root_url: vars.grafana_root_url,
            },
          } + (
            if vars.grafana_keycloak_enable then
              {
                'auth.generic_oauth': {
                  enabled: true,
                  allow_sign_up: true,
                  email_attribute_path: 'email',
                  scopes: 'openid email profile offline_access roles',
                  groups_attribute_path: 'groups',
                  login_attribute_path: 'username',
                  name_attribute_path: 'full_name',
                  name: 'Keycloak',
                  auth_url: vars.grafana_keycloak_url + '/auth/realms/' + vars.grafana_keycloak_realm + '/protocol/openid-connect/auth',
                  token_url: vars.grafana_keycloak_url + '/auth/realms/' + vars.grafana_keycloak_realm + '/protocol/openid-connect/token',
                  api_url: vars.grafana_keycloak_url + '/auth/realms/' + vars.grafana_keycloak_realm + '/protocol/openid-connect/userinfo',
                  client_id: vars.grafana_keycloak_client_id,
                  // Make sure your client role has exact the same name, case sensitive it is.
                  role_attribute_path: "contains(roles[*], 'Admin') && 'Admin' || contains(roles[*], 'Editor') && 'Editor' || 'Viewer'",

                },
              }
            else {}
          ),
        },
      },
    },
    alertmanager+: {
      alertmanager+: {
        spec+: {
          replicas: 1,
          resources: vars.alertmanager_resources,
          secrets: (
            if std.objectHas(vars, 'connect_obmondo') && vars.connect_obmondo then [
              'obmondo-clientcert',
              'alertmanager-main',
            ] else []
          ),
          storage+: {
            volumeClaimTemplate: {
              spec: {
                accessModes: ['ReadWriteOnce'],
                resources: {
                  requests: {
                    storage: '1Gi',  // <-- set desired size here
                  },
                },
              },
            },
          },
        },
      },
      networkPolicy+: {
        spec+: {
          ingress+: [
            {
              from: [{
                namespaceSelector: {
                  matchLabels: {
                    'kubernetes.io/metadata.name': 'traefik',
                  },
                },
                podSelector: {
                  matchLabels: {
                    'app.kubernetes.io/name': 'traefik',
                  },
                },
              }],
              ports: [{
                port: 9093,
                protocol: 'TCP',
              }],
            },
          ],
        },
      },
    } + (
      if std.objectHas(vars, 'connect_obmondo') && vars.connect_obmondo then {
        secret:: {},
      } else {}
    ),
  } + (
    if std.objectHas(vars, 'grafana_ingress_host') then
      {
        ingress+:: {
          grafana: utils.ingress(
            'grafana',
            $.values.common.namespace,
            [{
              host: vars.grafana_ingress_host,
              http: {
                paths: [{
                  path: '/',
                  pathType: 'Prefix',
                  backend: {
                    service: {
                      name: 'grafana',
                      port: {
                        name: 'http',
                      },
                    },
                  },
                }],
              },
            }],
            [{
              secretName: 'kube-prometheus-grafana-tls',
              hosts: [
                vars.grafana_ingress_host,
              ],
            }],
            vars.grafana_ingress_annotations,
          ),
        },
      } else {}
  ) + (
    if std.objectHas(vars, 'alertmanager_ingress_host') then
      {
        ingress+:: {
          alertmanager: utils.ingress(
            'alertmanager',
            $.values.common.namespace,
            [{
              host: vars.alertmanager_ingress_host,
              http: {
                paths: [{
                  path: '/',
                  pathType: 'Prefix',
                  backend: {
                    service: {
                      name: 'alertmanager-main',
                      port: {
                        name: 'web',
                      },
                    },
                  },
                }],
              },
            }],
            [{
              secretName: 'kube-prometheus-alertmanager-tls',
              hosts: [
                vars.alertmanager_ingress_host,
              ],
            }],
            vars.alertmanager_ingress_annotations,
          ),
        },
      } else {}
  ) + (
    if std.objectHas(vars, 'prometheus_ingress_host') then
      {
        ingress+:: {
          prometheus: utils.ingress(
            'prometheus-k8s',
            $.values.common.namespace,
            [{
              host: vars.prometheus_ingress_host,
              http: {
                paths: [{
                  path: '/',
                  pathType: 'Prefix',
                  backend: {
                    service: {
                      name: 'prometheus-k8s',
                      port: {
                        name: 'web',
                      },
                    },
                  },
                }],
              },
            }],
            [{
              secretName: 'kube-prometheus-prometheus-tls',
              hosts: [
                vars.prometheus_ingress_host,
              ],
            }],
            vars.prometheus_ingress_annotations,
          ),
        },
      } else {}
  );

{
  'setup/0namespace-namespace': kp.kubePrometheus.namespace +
                                ({
                                   metadata+: {
                                     labels:
                                       { monitoring: 'kube-prometheus-stack' },
                                   },
                                 }),
} +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
(if vars['blackbox-exporter'] then { ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } else {}) +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) } +
// Ordering matters! This next absurd object **has** to come after the inclusion
// of `kubernetesControlPlane` above -- otherwise we'll overwrite the object and
// remove our filtering.
{ 'kubernetes-prometheusRule': kp.kubernetesControlPlane.prometheusRule {
  spec+: {
    groups: std.filter((
              function(o)
                std.objectHas(o, 'rules') && o.name != 'kubernetes-system-apiserver' && o.name != 'kubernetes-resources'
            ), kp.kubernetesControlPlane.prometheusRule.spec.groups)
            +
            [{
              name: 'kubernetes-system-apiserver',
              rules:
                std.filter(
                  (
                    function(o)
                      std.objectHas(o, 'alert') &&
                      o.alert != 'KubeClientCertificateExpiration'
                  ),
                  std.filter((
                    function(o)
                      std.objectHas(o, 'rules') && o.name == 'kubernetes-system-apiserver'
                  ), kp.kubernetesControlPlane.prometheusRule.spec.groups)[0].rules
                ),
            }]
            +
            [{
              name: 'kubernetes-resources',
              rules:
                std.filter(
                  (
                    function(o)
                      std.objectHas(o, 'alert') &&
                      !std.member(o.alert, 'KubeCPUOvercommit') &&
                      !std.member(o.alert, 'KubeMemoryOvercommit')
                  ),
                  std.filter((
                    function(o)
                      std.objectHas(o, 'rules') && o.name == 'kubernetes-resources'
                  ), kp.kubernetesControlPlane.prometheusRule.spec.groups)[0].rules
                ),
            }],
  },
} } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['argocd-application-prometheus-rules' + name]: kp.argocdApplications[name] for name in std.objectFields(kp.argocdApplications) } +
(
  // Need to figure out elseif
  // if vars != 'gke' || vars != 'azure' didnt worked
  if vars.platform != 'gke' then {
    ['prometheus-adapter-' + name]: kp.prometheusAdapter[name]
    for name in std.objectFields(kp.prometheusAdapter)
  } else {}
) +
(if std.objectHas(vars, 'grafana_ingress_host') then { [name + '-ingress']: kp.ingress[name] for name in std.objectFields(kp.ingress) } else {}) +
(if std.objectHas(vars, 'prometheus_ingress_host') then { [name + '-ingress']: kp.ingress[name] for name in std.objectFields(kp.ingress) } else {}) +
// Rendering prometheusRules object. This is an object compatible with prometheus-operator CRD definition for prometheusRule
{ [o._config.name + '-prometheus-rules']: o.prometheusRules for o in std.filter((function(o) o.prometheusRules != null), mixins) }
