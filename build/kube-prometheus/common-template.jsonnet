local addMixin = import 'lib/addmixin.libsonnet';
local utils = import 'lib/utils.libsonnet';
local validate = import 'lib/validate.libsonnet';

local remove_nulls = (
  function(arr)
    std.filter((function(o) o != null), arr)
);

local ext_vars = std.extVar('vars');

local blackboxProbe = function(probe) {
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'Probe',
  metadata: {
    name: 'blackbox-probe-' + probe.name,
    namespace: 'monitoring',
    labels: { 'app.kubernetes.io/managed-by': 'kubeaid' },
  },
  spec: {
    interval: std.get(probe, 'interval', '60s'),
    [if std.objectHas(probe, 'scrapeTimeout') then 'scrapeTimeout']: probe.scrapeTimeout,
    module: std.get(probe, 'module', 'http_2xx'),
    prober: { url: 'blackbox-exporter.monitoring.svc.cluster.local:19115' },
    [if std.objectHas(probe, 'tlsConfig') then 'tlsConfig']: probe.tlsConfig,
    targets: {
      staticConfig: {
        [if std.objectHas(probe, 'labels') then 'labels']: probe.labels,
        static: ['https://' + probe.host],
      },
    },
  },
};

local default_vars = import 'lib/default_vars.libsonnet';
local default_kubeaid_apps_vars = std.parseYaml(importstr 'lib/default_kubeaid_apps_vars.yaml');

local vars = default_vars + ext_vars + default_kubeaid_apps_vars;

local _validationErrors = validate(vars);
assert std.length(_validationErrors) == 0 :
       '\n\nVars validation failed:\n' + std.join('\n', ['  - ' + e for e in _validationErrors]) + '\n';

local mixins = remove_nulls([
  addMixin(
    'ceph',
    (import 'github.com/obmondo/ceph/monitoring/ceph-mixin/mixin.libsonnet'),
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
    'hpa-maxed-out',
    (import 'mixins/hpa-maxed-out/mixin.libsonnet'),
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
  addMixin(
    'blackbox-exporter',
    (import 'mixins/blackbox-exporter/mixin.libsonnet'),
    vars,
  ),
  addMixin(
    'orphan-pvc',
    (import 'mixins/orphan-pvc/mixin.libsonnet'),
    vars,
  ),
]);

local scrape_namespaces = std.uniq(std.sort(std.flattenArrays(
  [
    vars.prometheus_scrape_namespaces,
  ] + [
    ['argocd'],
    ['cert-manager'],
    ['traefik'],
    ['monitoring'],
  ] + (
    if std.objectHas(vars.addMixins, 'sealedsecrets') && vars.addMixins.sealedsecrets then
      [
        ['sealed-secrets'],
      ]
    else []
  ) + (
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
  (import 'lib/drop-kubelet-metrics-endpoints.libsonnet') +
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
          externalLabels: {
            product: 'kubeaid',
          } + if std.objectHas(vars, 'connect_obmondo') && vars.connect_obmondo then (
            local certname = std.get(vars, 'certname', '');
            local parts = std.split(certname, '.');
            local is_valid_certname = std.length(parts) == 2 &&
                                      std.length(parts[1]) >= 7 &&
                                      std.length(parts[1]) <= 10;
            assert is_valid_certname :
                   'certname is required when connect_obmondo is true and must match "<cluster>.<customerid>" ' +
                   'where customerid is 7-10 chars (got: "%s")' % certname;
            {
              certname: certname,
            }
          ) else {},
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
        } + (
          // Opt-in remote-write receiver + wider TSDB out-of-order window
          // for backdated samples (migrations, backfills). Off by default.
          local rwr = std.get(vars.prometheus, 'remoteWriteReceiver', {});
          if std.get(rwr, 'enabled', false) then {
            enableRemoteWriteReceiver: true,
            tsdb+: {
              outOfOrderTimeWindow: std.get(rwr, 'outOfOrderTimeWindow', '7d'),
            },
          } else {}
        ) + if std.objectHas(vars.prometheus, 'remoteWrite') then (
          {
            remoteWrite+: [
              local defaults = {
                maxSamplesPerSend: 500,
              };

              local qc =
                if std.objectHas(remoteWrite, 'queueConfig') && remoteWrite.queueConfig != null
                then remoteWrite.queueConfig
                else {};

              {
                url: remoteWrite.url,
                remoteTimeout: std.get(remoteWrite, 'remoteTimeout', '60s'),
                queueConfig: defaults + qc,

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
                    matchExpressions: [{
                      key: 'app.kubernetes.io/name',
                      operator: 'In',
                      values: ['obmondo-k8s-agent', 'kubeaid-agent'],
                    }],
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
      blackboxExporter+: {
        resources: vars.blackbox_exporter_resources,
        modules+: vars.blackbox_exporter_modules,
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
          [dashboard]: mixin.grafanaDashboards[dashboard]
          for mixin in mixins
          if mixin.grafanaDashboards != null
          for dashboard in std.objectFields(mixin.grafanaDashboards)
        },
        folderDashboards+:: vars.grafana_dashboards,
        datasources: (
          [
            {
              name: 'prometheus',
              orgId: 1,
              type: 'prometheus',
              url: 'http://prometheus-k8s.monitoring.svc:9090',
              version: 1,
              access: 'proxy',
              editable: false,
            },
          ] + if std.objectHas(vars, 'grafana_external_datasources') then vars.grafana_external_datasources else []
        ),
        analytics+: {
          check_for_updates: false,
        },
        env: (
          (
            if vars.grafana_keycloak_enable then [
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
            ] else []
          ) + if std.objectHas(vars, 'grafana_external_env_vars') then vars.grafana_external_env_vars else []
        ),
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
              metadata: {
                labels: {
                  'velero.io/exclude-from-backup': 'true',
                },
              },
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
            {
              // Allow the kubeaid-agent in the obmondo namespace to poll
              // Alertmanager for active alerts.
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      'kubernetes.io/metadata.name': 'obmondo',
                    },
                  },
                  podSelector: {
                    matchLabels: {
                      'app.kubernetes.io/name': 'kubeaid-agent',
                    },
                  },
                },
              ],
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
{ ['kube-state-metrics-' + name]: if name == 'deployment' then kp.kubeStateMetrics[name] {
  spec+: { template+: { spec+: { containers: std.map(function(c) if c.name == 'kube-state-metrics' then c { args+: ['--metric-labels-allowlist=nodes=[beta.kubernetes.io/instance-type,kubernetes.io/hostname]'] } else c, super.containers) } } },
} else kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) } +
// Ordering matters! This next absurd object **has** to come after the inclusion
// of `kubernetesControlPlane` above -- otherwise we'll overwrite the object and
// remove our filtering.
{ 'kubernetes-prometheusRule': kp.kubernetesControlPlane.prometheusRule {
  spec+: {
    groups: std.map(
      (
        function(group)
          if group.name == 'kubernetes-apps' then
            group {
              rules: (
                local hpaReplacement = std.filter(
                  function(mixin) mixin._config.name == 'hpa-maxed-out',
                  mixins
                );
                if std.length(hpaReplacement) > 0 then
                  std.filter(
                    function(rule) !std.objectHas(rule, 'alert') || rule.alert != 'KubeHpaMaxedOut',
                    group.rules
                  ) + hpaReplacement[0].prometheusRules.spec.groups[0].rules
                else
                  group.rules
              ),
            }
          else if group.name == 'kubernetes-system-apiserver' then
            group {
              rules: std.filter(
                (
                  function(o)
                    std.objectHas(o, 'alert') &&
                    o.alert != 'KubeClientCertificateExpiration'
                ),
                group.rules
              ),
            }
          else if group.name == 'kubernetes-resources' then
            group {
              rules: std.filter(
                (
                  function(o)
                    std.objectHas(o, 'alert') &&
                    !std.member(o.alert, 'KubeCPUOvercommit') &&
                    !std.member(o.alert, 'KubeMemoryOvercommit')
                ),
                group.rules
              ),
            }
          else
            group
      ),
      kp.kubernetesControlPlane.prometheusRule.spec.groups
    ),
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
{ [o._config.name + '-prometheus-rules']: o.prometheusRules for o in std.filter((function(o) o.prometheusRules != null), mixins) } +
(if std.objectHas(vars, 'prometheus_ingress_host') then {
   'blackbox-probe-prometheus': blackboxProbe({ name: 'prometheus', host: vars.prometheus_ingress_host }),
 } else {}) +
(if std.objectHas(vars, 'grafana_ingress_host') then {
   'blackbox-probe-grafana': blackboxProbe({ name: 'grafana', host: vars.grafana_ingress_host }),
 } else {}) +
(if std.objectHas(vars, 'alertmanager_ingress_host') then {
   'blackbox-probe-alertmanager': blackboxProbe({ name: 'alertmanager', host: vars.alertmanager_ingress_host }),
 } else {})
