// Run with:
//   jsonnet -J libraries/v0.13.0/vendor tests/addmixin_test.jsonnet
local addMixin = import '../lib/addmixin.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

// ── cluster config fixtures (mirrors real bw7 customer configs) ────────────

// Shared base that all bw7 clusters have in common
local bw7Base = {
  platform: 'kops',
  namespace: 'monitoring',
  labels: { prometheus: 'k8s' },
  mixin_configs: {},
};

// development.bw7.io / dmz / staging / production — velero on, ceph off, no hpa-maxed-out
local cfgVeleroOnly = bw7Base {
  addMixins: { ceph: false, velero: true },
};

// k8s.ops.blackwoodseven.com — velero + opensearch, still no hpa-maxed-out
local cfgVeleroAndOpensearch = bw7Base {
  addMixins: { ceph: false, velero: true, opensearch: true },
};

// minimal: connect_obmondo false, v0.11.0, everything still off for hpa-maxed-out
local cfgMinimal = bw7Base {
  addMixins: { ceph: false, velero: true },
};

// Hypothetical future config that enables hpa-maxed-out
local cfgWithHpa = bw7Base {
  addMixins: { ceph: false, velero: true, 'hpa-maxed-out': true },
};

// Everything disabled
local cfgAllOff = bw7Base {
  addMixins: { ceph: false, velero: false, 'hpa-maxed-out': false },
};

// ── minimal mixin stubs ────────────────────────────────────────────────────

local mixinAlerts(groupName, alertName) = {
  _config+:: {},
  prometheusAlerts+:: {
    groups+: [{
      name: groupName,
      rules: [{
        alert: alertName,
        expr: 'up == 0',
        'for': '5m',
        labels: { severity: 'warning' },
        annotations: { summary: alertName + ' fired' },
      }],
    }],
  },
};

local veleroMixinObj = mixinAlerts('velero', 'VeleroBackupFailed');
local cephMixinObj = mixinAlerts('ceph', 'CephHealthWarning');
local hpaMixinObj = mixinAlerts('kubernetes-apps', 'KubeHpaMaxedOut');
local opensearchMixinObj = mixinAlerts('opensearch', 'OpenSearchClusterRed');

// Dashboard keys become ConfigMap and volume names ('grafana-dashboard-<key>'),
// which must be lowercase. Upstream mixins such as cilium-enterprise-mixin
// ship keys like 'cilium-L3-policy.json'.
local mixedCaseDashboardsMixinObj = {
  _config+:: {},
  grafanaDashboards+:: {
    'cilium-L3-policy.json': { uid: 'l3-policy' },
    'cilium-L7-proxy.json': { uid: 'l7-proxy' },
    'overview.json': { uid: 'overview' },
  },
};

local cfgMixedCaseDashboards = {
  namespace: 'monitoring',
  labels: { prometheus: 'k8s' },
  mixin_configs: {},
  addMixins: { dashboards: true },
};

local cfgMixedCaseDashboardsInFolder = cfgMixedCaseDashboards {
  mixin_configs: { dashboards: { dashboardFolder: 'Cilium' } },
};

// ── HPA replacement logic (same as common-template.jsonnet after the fix) ──

local hpaReplacementRules(mixins, groupRules) =
  local hpaReplacement = std.filter(
    function(m) m._config.name == 'hpa-maxed-out',
    mixins
  );
  if std.length(hpaReplacement) > 0 then
    std.filter(
      function(rule) !std.objectHas(rule, 'alert') || rule.alert != 'KubeHpaMaxedOut',
      groupRules
    ) + hpaReplacement[0].prometheusRules.spec.groups[0].rules
  else
    groupRules;

// Build a mixins list the same way common-template.jsonnet does (remove nulls)
local buildMixins(cfg) =
  local raw = [
    addMixin('velero', veleroMixinObj, cfg),
    addMixin('ceph', cephMixinObj, cfg),
    addMixin('hpa-maxed-out', hpaMixinObj, cfg),
    addMixin('opensearch', opensearchMixinObj, cfg),
  ];
  std.filter(function(m) m != null, raw);

// ── shared rule fixtures ───────────────────────────────────────────────────

local hpaOriginalRule = {
  alert: 'KubeHpaMaxedOut',
  expr: 'kube_hpa_status_current_replicas == kube_hpa_spec_max_replicas',
  'for': '15m',
  labels: { severity: 'warning' },
};

local otherRule = {
  alert: 'KubePodCrashLooping',
  expr: 'rate(kube_pod_container_status_restarts_total[5m]) > 0',
  'for': '15m',
  labels: { severity: 'warning' },
};

// ── tests ──────────────────────────────────────────────────────────────────

test.suite({

  // ── velero-only config (development / dmz / staging / production) ────────

  // velero enabled → mixin object returned
  testVeleroOnly_veleroEnabled: {
    actual: addMixin('velero', veleroMixinObj, cfgVeleroOnly) != null,
    expect: true,
  },

  // ceph explicitly false → null (removed from list)
  testVeleroOnly_cephDisabled: {
    actual: addMixin('ceph', cephMixinObj, cfgVeleroOnly),
    expect: null,
  },

  // hpa-maxed-out absent from addMixins → null
  testVeleroOnly_hpaAbsent: {
    actual: addMixin('hpa-maxed-out', hpaMixinObj, cfgVeleroOnly),
    expect: null,
  },

  // buildMixins with velero-only config yields exactly one mixin (velero)
  testVeleroOnly_mixinCount: {
    actual: std.length(buildMixins(cfgVeleroOnly)),
    expect: 1,
  },

  testVeleroOnly_mixinName: {
    actual: buildMixins(cfgVeleroOnly)[0].name,
    expect: 'velero',
  },

  // HPA replacement: hpa-maxed-out not in mixins → original rules preserved
  // (this is the bug that was fixed — it previously crashed with "Index 0 out of bounds")
  testVeleroOnly_hpaReplacement_preservesOriginalRules: {
    local mixins = buildMixins(cfgVeleroOnly),
    local rules = hpaReplacementRules(mixins, [hpaOriginalRule, otherRule]),
    actual: std.length(rules),
    expect: 2,
  },

  testVeleroOnly_hpaReplacement_hpaRuleKept: {
    local mixins = buildMixins(cfgVeleroOnly),
    local rules = hpaReplacementRules(mixins, [hpaOriginalRule, otherRule]),
    actual: rules[0].alert,
    expect: 'KubeHpaMaxedOut',
  },

  // ── ops config (velero + opensearch) ────────────────────────────────────

  testOps_opensearchEnabled: {
    actual: addMixin('opensearch', opensearchMixinObj, cfgVeleroAndOpensearch) != null,
    expect: true,
  },

  testOps_cephDisabled: {
    actual: addMixin('ceph', cephMixinObj, cfgVeleroAndOpensearch),
    expect: null,
  },

  // two mixins active: velero + opensearch
  testOps_mixinCount: {
    actual: std.length(buildMixins(cfgVeleroAndOpensearch)),
    expect: 2,
  },

  testOps_mixinNames: {
    actual: std.sort(std.map(function(m) m.name, buildMixins(cfgVeleroAndOpensearch))),
    expect: ['opensearch', 'velero'],
  },

  // HPA replacement still safe with two unrelated mixins in the list
  testOps_hpaReplacement_nocrash: {
    local mixins = buildMixins(cfgVeleroAndOpensearch),
    local rules = hpaReplacementRules(mixins, [hpaOriginalRule, otherRule]),
    actual: std.length(rules),
    expect: 2,
  },

  // ── hypothetical config with hpa-maxed-out enabled ───────────────────────

  testWithHpa_hpaEnabled: {
    actual: addMixin('hpa-maxed-out', hpaMixinObj, cfgWithHpa) != null,
    expect: true,
  },

  // three mixins active: velero + hpa-maxed-out (ceph still off)
  testWithHpa_mixinCount: {
    actual: std.length(buildMixins(cfgWithHpa)),
    expect: 2,
  },

  // HPA replacement: strips original KubeHpaMaxedOut and appends mixin version
  testWithHpa_hpaReplacement_stripsOriginal: {
    local mixins = buildMixins(cfgWithHpa),
    local rules = hpaReplacementRules(mixins, [hpaOriginalRule, otherRule]),
    actual: std.map(function(r) r.alert, rules),
    expect: ['KubePodCrashLooping', 'KubeHpaMaxedOut'],
  },

  // when group has no original KubeHpaMaxedOut rule, mixin is simply appended
  testWithHpa_hpaReplacement_appendsWhenAbsent: {
    local mixins = buildMixins(cfgWithHpa),
    local rules = hpaReplacementRules(mixins, [otherRule]),
    actual: std.length(rules),
    expect: 2,
  },

  // ── all-off config ───────────────────────────────────────────────────────

  testAllOff_noMixins: {
    actual: std.length(buildMixins(cfgAllOff)),
    expect: 0,
  },

  testAllOff_hpaReplacement_preservesRules: {
    local rules = hpaReplacementRules([], [hpaOriginalRule, otherRule]),
    actual: std.length(rules),
    expect: 2,
  },

  // ── metadata correctness ─────────────────────────────────────────────────

  testVeleroMixin_prometheusRuleMetadataName: {
    actual: addMixin('velero', veleroMixinObj, cfgVeleroOnly).prometheusRules.metadata.name,
    expect: 'velero',
  },

  testVeleroMixin_prometheusRuleNamespace: {
    actual: addMixin('velero', veleroMixinObj, cfgVeleroOnly).prometheusRules.metadata.namespace,
    expect: 'monitoring',
  },

  testVeleroMixin_configNameMatchesMixinArg: {
    actual: addMixin('velero', veleroMixinObj, cfgVeleroOnly)._config.name,
    expect: 'velero',
  },

  // ── dashboard names must be valid Kubernetes object names ────────────────

  testDashboards_keysLowercased: {
    actual: std.objectFields(addMixin('dashboards', mixedCaseDashboardsMixinObj, cfgMixedCaseDashboards).grafanaDashboards),
    expect: ['cilium-l3-policy.json', 'cilium-l7-proxy.json', 'overview.json'],
  },

  testDashboards_contentKept: {
    actual: addMixin('dashboards', mixedCaseDashboardsMixinObj, cfgMixedCaseDashboards).grafanaDashboards['cilium-l3-policy.json'].uid,
    expect: 'l3-policy',
  },

  testDashboards_keysLowercasedInFolder: {
    actual: std.objectFields(addMixin('dashboards', mixedCaseDashboardsMixinObj, cfgMixedCaseDashboardsInFolder).grafanaDashboards.Cilium),
    expect: ['cilium-l3-policy.json', 'cilium-l7-proxy.json', 'overview.json'],
  },

}).verify
