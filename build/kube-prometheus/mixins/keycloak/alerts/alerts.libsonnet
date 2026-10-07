{
  prometheusAlerts+:: {
    local c = $._config,

    // Failures are event="login" with a non-empty `error` label; successes have no `error` label.
    // Guarded by a minimum volume so one typo on a quiet client does not alert.
    local loginFailureRatio(threshold) = |||
      sum by (realm, client_id) (increase(keycloak_user_events_total{event="login", error!=""}[%(w)s]))
        /
      sum by (realm, client_id) (increase(keycloak_user_events_total{event="login"}[%(w)s]))
        > %(t)s
      and on (realm, client_id)
      sum by (realm, client_id) (increase(keycloak_user_events_total{event="login"}[%(w)s])) >= %(m)s
    ||| % { w: c.loginWindow, t: threshold, m: c.minLoginAttempts },

    groups+: [
      {
        name: 'keycloak-availability',
        rules: [
          {
            // Pod is running but /metrics cannot be scraped.
            alert: 'KeycloakTargetScrapeFailing',
            expr: 'up{%(sel)s} == 0' % { sel: c.keycloakSelector },
            'for': '2m',
            labels: { severity: 'critical' },
            annotations: {
              summary: 'Cannot scrape Keycloak instance {{ $labels.instance }}',
              description: 'Prometheus cannot scrape {{ $labels.instance }} (port 9000 /metrics) for 2 minutes.',
            },
          },
          {
            // Pod is gone entirely: the `up` series disappears instead of becoming 0.
            alert: 'KeycloakTargetsMissing',
            expr: 'absent(up{%(sel)s})' % { sel: c.keycloakSelector },
            'for': '3m',
            labels: { severity: 'critical' },
            annotations: {
              summary: 'No Keycloak targets found in Prometheus',
              description: 'No `up` series exists for Keycloak. All pods are down, or the ServiceMonitor/job selector is wrong.',
            },
          },
          {
            // Partial outage (e.g. 1 of 3 replicas). Requires kube-state-metrics.
            alert: 'KeycloakReplicasNotReady',
            expr: |||
              kube_statefulset_status_replicas_ready{%(sel)s}
                <
              kube_statefulset_replicas{%(sel)s}
            ||| % { sel: c.keycloakStatefulSetSelector },
            'for': '5m',
            labels: { severity: 'critical' },
            annotations: {
              summary: 'Keycloak has fewer ready replicas than desired',
              description: '{{ $labels.statefulset }} has {{ $value }} ready replicas, below the desired count.',
            },
          },
          {
            alert: 'KeycloakHighHttp5xxRate',
            expr: |||
              sum(rate(http_server_requests_seconds_count{%(sel)s, status=~"5.."}[5m]))
                /
              sum(rate(http_server_requests_seconds_count{%(sel)s}[5m]))
                > %(t)s
            ||| % { sel: c.keycloakSelector, t: c.http5xxRatio },
            'for': '5m',
            labels: { severity: 'critical' },
            annotations: {
              summary: 'Keycloak 5xx ratio is high',
              description: '{{ $value | humanizePercentage }} of requests are failing with 5xx.',
            },
          },
          {
            alert: 'KeycloakHighTokenLatencyP95',
            expr: |||
              histogram_quantile(0.95,
                sum by (le) (
                  rate(http_server_requests_seconds_bucket{%(sel)s, uri=~"%(uri)s"}[5m])
                )
              ) > %(t)s
            ||| % { sel: c.keycloakSelector, uri: c.protocolUriRegex, t: c.tokenLatencyP95Seconds },
            'for': '10m',
            labels: { severity: 'warning' },
            annotations: {
              summary: 'Keycloak p95 protocol endpoint latency is high',
              description: 'p95 latency is {{ $value | humanizeDuration }}. Check DB pool, CPU and password hashing load.',
            },
          },
          {
            alert: 'KeycloakTooManyActiveRequests',
            expr: 'sum by (instance) (http_server_active_requests{%(sel)s}) > %(t)s' % { sel: c.keycloakSelector, t: c.activeRequests },
            'for': '5m',
            labels: { severity: 'warning' },
            annotations: {
              summary: 'High number of in-flight requests on {{ $labels.instance }}',
              description: '{{ $value }} active requests. Possible saturation or slow dependencies.',
            },
          },
        ],
      },
      {
        name: 'keycloak-logins',
        rules: [
          {
            // The warning also matches when critical fires: inhibit it in Alertmanager (see README).
            alert: 'KeycloakLoginFailureRatioHigh',
            expr: loginFailureRatio(c.loginFailureRatioWarning),
            'for': '10m',
            labels: { severity: 'warning' },
            annotations: {
              summary: 'High login failure ratio for client {{ $labels.client_id }} in realm {{ $labels.realm }}',
              description: '{{ $value | humanizePercentage }} of logins failed. Break failures down by cause: sum by (error) (increase(keycloak_user_events_total{event="login", error!="", realm="{{ $labels.realm }}"}[10m]))',
            },
          },
          {
            alert: 'KeycloakLoginFailureRatioCritical',
            expr: loginFailureRatio(c.loginFailureRatioCritical),
            'for': '5m',
            labels: { severity: 'critical' },
            annotations: {
              summary: 'Most logins are failing for client {{ $labels.client_id }} in realm {{ $labels.realm }}',
              description: '{{ $value | humanizePercentage }} of logins failed. Likely a broken login flow (IdP, user federation, client config) or an attack.',
            },
          },
          {
            // Probing for non-existent accounts is a stronger credential-stuffing signal than wrong passwords.
            alert: 'KeycloakUserNotFoundSpike',
            expr: 'sum by (realm) (increase(keycloak_user_events_total{event="login", error="user_not_found"}[%(w)s])) > %(t)s' % { w: c.loginWindow, t: c.userNotFoundThreshold },
            'for': '5m',
            labels: { severity: 'warning' },
            annotations: {
              summary: 'Many logins for unknown users in realm {{ $labels.realm }}',
              description: '{{ $value }} login attempts used usernames that do not exist. Possible enumeration or credential stuffing.',
            },
          },
          {
            // 5m failure rate vs the previous hour. The floor stops tiny baselines making blips look like spikes.
            // If the previous hour had zero failures the baseline is absent and this stays silent;
            // the ratio and user_not_found alerts cover that case.
            alert: 'KeycloakLoginErrorSpike',
            expr: |||
              sum by (realm) (rate(keycloak_user_events_total{event="login", error!=""}[5m]))
                >
              %(m)s * sum by (realm) (rate(keycloak_user_events_total{event="login", error!=""}[1h] offset 5m)) + %(f)s
            ||| % { m: c.loginSpikeMultiplier, f: c.loginSpikeFloor },
            'for': '5m',
            labels: { severity: 'warning' },
            annotations: {
              summary: 'Login error spike in realm {{ $labels.realm }}',
              description: 'Login errors are well above the last hour\'s baseline. Check for brute-force attempts.',
            },
          },
          {
            alert: 'KeycloakNoLoginsObserved',
            expr: 'sum(increase(keycloak_user_events_total{event="login", error=""}[%(w)s])) == 0' % { w: c.noLoginsWindow },
            'for': c.noLoginsWindow,
            labels: { severity: 'info' },
            annotations: {
              summary: 'No successful logins observed',
              description: 'Either no traffic (expected off-hours) or a broken login flow. Tune or remove for low-traffic environments.',
            },
          },
        ],
      },
      {
        name: 'keycloak-database',
        rules: [
          {
            alert: 'KeycloakDbPoolExhausted',
            expr: 'agroal_available_count{%(sel)s} == 0' % { sel: c.keycloakSelector },
            'for': '2m',
            labels: { severity: 'critical' },
            annotations: {
              summary: 'DB connection pool exhausted on {{ $labels.instance }}',
              description: 'No available connections. Requests will queue and time out. Consider raising KC_DB_POOL_MAX_SIZE.',
            },
          },
          {
            alert: 'KeycloakDbPoolWaiters',
            expr: 'agroal_awaiting_count{%(sel)s} > 0' % { sel: c.keycloakSelector },
            'for': '5m',
            labels: { severity: 'warning' },
            annotations: {
              summary: 'Threads waiting for a DB connection on {{ $labels.instance }}',
              description: '{{ $value }} threads are blocked waiting for a connection.',
            },
          },
        ],
      },
      {
        name: 'keycloak-jvm',
        rules: [
          {
            alert: 'KeycloakHeapUsageHigh',
            expr: |||
              sum by (instance) (jvm_memory_used_bytes{%(sel)s, area="heap"})
                /
              sum by (instance) (jvm_memory_max_bytes{%(sel)s, area="heap"})
                > %(t)s
            ||| % { sel: c.keycloakSelector, t: c.heapRatio },
            'for': '10m',
            labels: { severity: 'warning' },
            annotations: {
              summary: 'Heap usage is high on {{ $labels.instance }}',
              description: 'Heap usage is {{ $value | humanizePercentage }}. Risk of OOM or GC thrash.',
            },
          },
          {
            alert: 'KeycloakLongGcPauses',
            expr: 'rate(jvm_gc_pause_seconds_sum{%(sel)s}[5m]) > %(t)s' % { sel: c.keycloakSelector, t: c.gcTimeRatio },
            'for': '10m',
            labels: { severity: 'warning' },
            annotations: {
              summary: 'Excessive GC time on {{ $labels.instance }}',
              description: 'A large share of wall time is spent in GC pauses.',
            },
          },
          {
            alert: 'KeycloakHighCpu',
            expr: 'process_cpu_usage{%(sel)s} > %(t)s' % { sel: c.keycloakSelector, t: c.cpuRatio },
            'for': '15m',
            labels: { severity: 'warning' },
            annotations: {
              summary: 'High CPU usage on {{ $labels.instance }}',
              description: 'Often caused by password hashing under heavy login load.',
            },
          },
        ],
      },
    ],
  },
}
