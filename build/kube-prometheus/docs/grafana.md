# Grafana

## Adding Custom Dashboards via GitOps

- Open **Dashboard settings** in Grafana for the dashboard you want to add.
- Click **JSON Model** and copy the JSON into a file in your kubeaid-config repo.
- Reference it in your cluster vars file:

  ```jsonnet
  grafana_dashboards: {
    'Custom Grafana Folder': {
      'custom-dashboard.json': (import '../path/to/custom-dashboard.json'),
    },
  },
  ```

- Run the build script, push to your kubeaid-config repo, and sync the `kube-prometheus` ArgoCD app. The Grafana pod will restart and reflect the new dashboard.

### Persisting dashboard changes

- Save the changes in Grafana, copy the updated JSON model from **Dashboard Settings**.
- Overwrite `custom-dashboard.json` in your kubeaid-config repo.
- Run the build script, merge, and sync in ArgoCD (expect ConfigMap changes).

## Loki data sources

If [Loki](../../../argocd-helm-charts/loki/README.md) runs in the `monitoring` namespace of the same cluster:

```jsonnet
loki: {
  enable: true,
  tenants: ['prod', 'staging'],
},
```

Each tenant gets a `loki-<tenant>` data source that queries the query-frontend directly with the tenant in
the `X-Scope-OrgID` header, so no password is needed. Without `tenants` you get one `loki` data source with
no header, for a Loki with `auth_enabled: false`.

Use `settings` to change the data source, for example the URL in Monolithic mode, which has no query-frontend:

```jsonnet
loki: {
  enable: true,
  settings: { url: 'http://loki.monitoring.svc.cluster.local:3100' },
},
```

Use `jsonData+:` in `settings` to add to `jsonData` without replacing it.

## Response compression (gzip)

Grafana can gzip its HTTP responses (the frontend JavaScript, dashboard JSON, query results) before sending
them to the browser. That saves bandwidth, and costs Grafana memory: every compressed response holds its own
gzip buffers, and opening Grafana makes the browser fetch the whole frontend in parallel. With Grafana 13,
which compresses by default, one login takes 50 to 80 MB of extra memory, enough to get the pod OOMKilled.

KubeAid therefore turns compression off (`enable_gzip = false` in the `[server]` section of `grafana.ini`).
Responses are sent uncompressed, so they are 3 to 4 times larger on the wire. The browser caches the
frontend files after the first load.

To turn it on for a cluster, set this in the cluster vars file and raise the memory limit with it:

```jsonnet
grafana_enable_gzip: true,
grafana_resources: {
  limits: { memory: '512Mi' },
  requests: { cpu: '6m', memory: '256Mi' },
},
```

Run the build script, push to your kubeaid-config repo, and sync the `kube-prometheus` ArgoCD app.

## Adding the Alertmanager Secret

Use the [example config](../examples/alertmanager-config/alertmanager-main-slack.yaml) to create your `alertmanager-main` secret.

Seal it with your Slack URL:

```sh
kubectl create secret generic alertmanager-main \
  --dry-run=client --namespace monitoring \
  --from-literal=slack-url='https://your-slack-channel-url' -o yaml | \
  kubeseal --controller-namespace system --controller-name sealed-secrets \
  --namespace monitoring -o yaml --merge-into alertmanager-main.yaml
```

Or generate an empty sealed secret:

```sh
kubectl create secret generic alertmanager-main --dry-run=client -o yaml | \
  kubeseal --controller-namespace system --controller-name sealed-secrets \
  --format yaml --merge-into alertmanager-main.yaml
```

## Integrating Keycloak with Grafana

See [NOTES.md](../NOTES.md#integrate-keycloak-with-grafana).

## Resetting the Grafana Admin Password

```sh
GrafanaPod=$(kubectl get pods -n monitoring | grep grafana | awk '{print $1}')
kubectl exec -it $GrafanaPod -n monitoring -- grafana-cli admin reset-admin-password <new-password>
```

If that doesn't work, restart the pod:

```sh
kubectl delete pod $GrafanaPod -n monitoring
```

## Air-Gapped Deployment (Grafana Oncall Plugin)

By default Grafana downloads the `grafana-oncall-app` plugin from `grafana.com` at startup. In an air-gapped cluster this fails on every restart. The steps below serve the plugin from Harbor instead.

### Step 1 — Push the plugin to Harbor as an OCI artifact

Copy the plugin from the Grafana pod or download it:

```sh
kubectl cp <GRAFANA_POD>:/var/lib/grafana/plugins/grafana-oncall-app ./grafana-oncall-app
zip -r grafana-oncall-app.zip grafana-oncall-app/
oras push <HARBOR_URL>/<PROJECT>/grafana-oncall-app-plugin:<VERSION> \
  grafana-oncall-app.zip:application/zip
```

### Step 2 — Mirror the `oras` image to Harbor

```sh
docker pull ghcr.io/oras-project/oras:<VERSION>
docker tag  ghcr.io/oras-project/oras:<VERSION> <HARBOR_URL>/<PROJECT>/oras:<VERSION>
docker push <HARBOR_URL>/<PROJECT>/oras:<VERSION>
```

### Step 3 — Create Kubernetes secrets

```sh
# imagePullSecret for the oras init container
kubectl create secret docker-registry harbor-pull-secret \
  --docker-server=<HARBOR_URL> \
  --docker-username=<robot-account> \
  --docker-password=<robot-token> \
  --dry-run=client -o yaml | kubeseal --format yaml > harbor-pull-secret-sealed.yaml

# Registry credentials for oras pull inside the init container
kubectl create secret generic harbor-registry-credentials \
  --from-literal=username=<robot-account> \
  --from-literal=password=<robot-token> \
  --dry-run=client -o yaml | kubeseal --format yaml > harbor-registry-credentials-sealed.yaml
```

Commit both sealed secret files to your kubeaid-config repo.

### Step 4 — Configure kubeaid-config values

```yaml
oncall:
  grafanaPluginInstall:
    enabled: true
  grafana:
    plugins: []
    grafana.ini:
      plugins:
        preinstall_sync_enabled: false
    env:
      GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS: grafana-oncall-app
    image:
      pullSecrets:
        - harbor-pull-secret
    extraInitContainers:
      - name: install-oncall-plugin
        image: <HARBOR_URL>/<PROJECT>/oras:<VERSION>
        command: [sh, /scripts/install-plugin.sh]
        env:
          - name: HARBOR_USER
            valueFrom:
              secretKeyRef:
                name: harbor-registry-credentials
                key: username
          - name: HARBOR_PASSWORD
            valueFrom:
              secretKeyRef:
                name: harbor-registry-credentials
                key: password
          - name: HARBOR_PLUGIN_REF
            valueFrom:
              secretKeyRef:
                name: harbor-registry-credentials
                key: plugin
        volumeMounts:
          - name: storage
            mountPath: /var/lib/grafana
          - name: plugin-install-script
            mountPath: /scripts
    extraVolumes:
      - name: plugin-install-script
        configMap:
          name: oncall-grafana-plugin-install
          defaultMode: 0755
      - name: provisioning
        configMap:
          name: helm-testing-grafana-plugin-provisioning
```

> **NOTE:** `extraInitContainers` and `extraVolumes` replace (not merge) subchart defaults — include the `provisioning` volume explicitly.

### Step 5 — Block egress to grafana.com

Enable `CiliumNetworkPolicy` to enforce that the Grafana pod cannot reach `grafana.com`.
