{
  _config+:: {
    // ---- Selectors -----------------------------------------------------
    // Matches your Keycloak scrape job(s). Used by the alerts.
    keycloakSelector: 'job=~".*keycloak.*"',
    // kube-state-metrics selector for the Keycloak StatefulSet (replica alert).
    // Use kube_deployment_* in alerts/alerts.libsonnet if you run a Deployment.
    keycloakStatefulSetSelector: 'namespace="keycloak", statefulset=~".*keycloak.*"',
    // Token/login endpoints for the latency alert.
    protocolUriRegex: '.*protocol.*',

    // ---- Dashboards ----------------------------------------------------
    // Upstream dashboards hardcode container="keycloak"; change it here if yours differs.
    dashboardContainer: 'keycloak',
    dashboardTags: ['keycloak', 'keycloak-mixin'],
    dashboardRefresh: '1m',
    datasourceVar: 'datasource',
    datasourceRegex: '',
    // Original upstream UIDs are kept so existing links keep working.
    dashboardUids: {
      troubleshooting: 'Mh1Ly1ZNz',
      capacityPlanning: 'dtvmgcVNk',
    },

    // ---- Alert thresholds ---------------------------------------------
    // Login events need KC_EVENT_METRICS_USER_ENABLED=true (Keycloak 26+).
    loginWindow: '10m',
    minLoginAttempts: 20,  // volume guard: ignore quiet clients
    loginFailureRatioWarning: 0.3,
    loginFailureRatioCritical: 0.7,
    userNotFoundThreshold: 50,  // per loginWindow
    loginSpikeMultiplier: 5,
    loginSpikeFloor: 0.1,  // failures/sec (~6 per minute)
    noLoginsWindow: '30m',

    http5xxRatio: 0.01,
    tokenLatencyP95Seconds: 1,  // needs KC_HTTP_METRICS_HISTOGRAMS_ENABLED=true
    activeRequests: 200,
    heapRatio: 0.85,
    gcTimeRatio: 0.1,
    cpuRatio: 0.85,
  },
}
