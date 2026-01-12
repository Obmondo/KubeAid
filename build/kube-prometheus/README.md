# kubeaid kube-prometheus build

Use `build.sh` to build prometheus manifests for a kubernetes cluster.
See the comment at the top of `build.sh` for how to use it.

For the Makefile, run `make setup` to install `jb`, initialize it and fetch the
`build.sh`, vendor and other files, although they have been created in the
`kube-prometheus` folder. `make build` compiles the manifests

Any ideas/suggestions are welcomed...
> **NOTE:** v0.16.0 is a special release. The upstream kube-prometheus v0.16.0 release had an issue, which we resolved by pointing the release to this Patch commit: [prometheus-operator/kube-prometheus#2733](https://github.com/prometheus-operator/kube-prometheus/pull/2733)
## Running

### Mac OS

Pay attention to all prerequisites.

Additionally do following two installations to run the build.sh :

```
brew install bash
brew install jsonnet
```

### Install prerequisites

This installs go

```sh
snap install go
export PATH=$PATH:$(go env GOPATH)/bin
```

This installs jsonnet tooling:

```sh
go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
go install github.com/brancz/gojsontoyaml@latest
go install github.com/google/go-jsonnet/cmd/jsonnet@latest
```

Setup the jsonnet file as per the requirement

- Look into [examples folder](./examples)

### Run the build script

Run this in the root of this repo, with the k8s config repo cloned next to it

```sh
./build/kube-prometheus/build.sh ../<your-kubeaid-config>/k8s/<cluster-name>
```

Example:

```log
$ ./build/kube-prometheus/build.sh ../<your-kubeaid-config>/k8s/<cluster-name>
INFO: 'build/kube-prometheus/libraries/main/vendor' doesn't exist; executing jsonnet-bundler
GET https://github.com/prometheus-operator/kube-prometheus/archive/64b19b69d5a6d82af8bbfb3a67538b0feca31042.tar.gz 200
GET https://github.com/prometheus/alertmanager/archive/a6d10bd5bc3f651e0ca04d47b981ed66e85a09a6.tar.gz 200
GET https://github.com/thanos-io/thanos/archive/f0e673a2e4860d8cffafba4c97955171e5c6cb2b.tar.gz 200
GET https://github.com/brancz/kubernetes-grafana/archive/1c4d84de1c059b55ce83fdd76fbb4f58530b7d55.tar.gz 200
GET https://github.com/grafana/grafana/archive/8c622c1ef626a6982e0a6353877dd02313988010.tar.gz 200
GET https://github.com/prometheus-operator/prometheus-operator/archive/90e243ea91e4f332d517b0a2c190df9d5c3026a9.tar.gz 200
GET https://github.com/kubernetes/kube-state-metrics/archive/eff2c0ed6d1af04f10773e73aeae8b17f23c2409.tar.gz 200
GET https://github.com/prometheus/prometheus/archive/c7be45d957dd90e605738d8b74482e7579da0db0.tar.gz 200
GET https://github.com/etcd-io/etcd/archive/be2929568f81080b20ef6812992f2e09c8dac91b.tar.gz 200
GET https://github.com/prometheus-operator/prometheus-operator/archive/90e243ea91e4f332d517b0a2c190df9d5c3026a9.tar.gz 200
GET https://github.com/kubernetes-monitoring/kubernetes-mixin/archive/a2196d1b3493c15117550df2fd35dbdf54e4fa0e.tar.gz 200
GET https://github.com/kubernetes/kube-state-metrics/archive/eff2c0ed6d1af04f10773e73aeae8b17f23c2409.tar.gz 200
GET https://github.com/prometheus/node_exporter/archive/9aae303a46c3153b75e4d32b0936b40e4ee0beeb.tar.gz 200
GET https://github.com/kubernetes-monitoring/kubernetes-mixin/archive/a2196d1b3493c15117550df2fd35dbdf54e4fa0e.tar.gz 200
GET https://github.com/grafana/grafonnet-lib/archive/6db00c292d3a1c71661fc875f90e0ec7caa538c2.tar.gz 200
GET https://github.com/grafana/jsonnet-libs/archive/98c3060877aa178f6bdfc6ac618fbe0043fc3de7.tar.gz 200
INFO: compiling jsonnet files into '../<your-kubeaid-config>/k8s/<cluster-name>/kube-prometheus'
```

## Upgrading

For upgrading vendor directories of existing versions, `update.sh` iterates over the versions present in `./build/kube-prometheus/libraries/`, and updates all other dependecies as per the `kubernetes-prometheus` tag/version.

```sh
./build/kube-prometheus/update.sh
```

For upgrading to a new version of kube-prometheus, for example to `v0.12.0` - change the
`kube_prometheus_version` variable in the jsonnet vars file of your kubernetes cluster config
(example: `k8s/<cluster-name>/<cluster-name>-vars.jsonnet`) and run the build script again.

```sh
./build/kube-prometheus/build.sh ../<your-kubeaid-config>/k8s/<cluster-name>
```

This script looks for the `kubernetes-prometheus` version/release tag in your kubernetes cluster config, and checks if the same version/release dir exists in KubeAid repo. If found, it builds manifests for your kubernetes cluster using those files.

If the mentioned version/release dir doesn't exists already (for eg: `main`), the script downloads it first, and then proceeds with the manifest building process. This way you can upgrade/downgrade with ease.

If `kube_prometheus_version` variable isn't present in the jsonnet vars file, it'll set it to `main` by default.

Note that you have to clone your kubeaid-config git repository seperately.

## Adding versions

If there's a kube-prometheus version which isn't already added in KubeAid, run the `add-version.sh` script to add it. All you need is to specify the version/tag, and no customer jsonnet file is required.

```sh
./build/kube-prometheus/add-version.sh <version-tag>
```

## Cleaning up

During the [Upgrading process](#upgrading) if you encounter error related to broken version dependencies, or the version/release vendor dirs are messed up, you can just delete the entire version dir and follow the [Upgrading process](#upgrading) again. This freshly fetches the version and its dependencies, and builds manifests in your kubeaid-config repository.

```sh
rm -rf ./build/kube-prometheus/libraries/v0.12.0/
```

## Prometheus operator options, set in common-template.jsonnet options

Options available as part of values.alertmanager are listed in
https://github.com/prometheus-operator/kube-prometheus/blob/main/jsonnet/kube-prometheus/components/alertmanager.libsonnet#L1-L72
Additionally ALL options for Alertmanager CR listed in
https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#alertmanagerspec are available
in jsonnet as alertmanager.alertmanager.spec Alertmanager mixin options are inherited from the mixin itself and are
available in https://github.com/prometheus/alertmanager/blob/main/doc/alertmanager-mixin/config.libsonnet

## Adding new mixins

- Install mixin into `kube-prometheus` release directories (currently manual). In the below we install it only into `<version-of-kube-prometheus>`, but this should be repeated for all the versions in use.

  ```sh
  cd build/kube-prometheus/libraries/<version-of-kube-prometheus>
  jb install github.com/bitnami-labs/sealed-secrets/contrib/prometheus-mixin@main
  ```

- Add the mixin to `common-template.json` and build.sh as well. For adding the Bitnami `sealed-secrets` mixin this diff was required:

  ```diff
  @@ -46,6 +46,7 @@ local kp =
     // (import 'kube-prometheus/addons/static-etcd.libsonnet') +
     // (import 'kube-prometheus/addons/custom-metrics.libsonnet') +
     // (import 'kube-prometheus/addons/external-metrics.libsonnet') +
  +  (import 'github.com/bitnami-labs/sealed-secrets/contrib/prometheus-mixin/mixin.libsonnet') +

     {
       values+:: {
  ```

  Note that the search path contains the full path of the file from the top of the `vendor` folder.

  Checkout how the 'velero' mixin has been added in `common-template.json`. You may need to import the local path of the mixin depending on your mixin. You should also set the value that decides whether this mixin should be used as true/false. See this snippet from `common-template.json`.

  ```
  addMixins: {
    ceph: true,
    sealedsecrets: true,
    etcd: true,
    velero: false,
    'cert-manager': true,
    'kubernetes-eol':true,
  }
  ```

- To add a custom prometheus rule as a mixin, create a mixin.libsonnet file in the relevant folder under the `mixins` folder and generate the `prometheus.yaml` for it. One way to do generate a YAML file from a .libsonnet file is using a jsonnet command similar to this:

```
jsonnet -e '(import "mixin.libsonnet").prometheusAlerts' | gojsontoyaml > prometheus.yaml
```
verify that new prometheus.yaml generated in the above step is valid
```
promtool check rules build/kube-prometheus/mixins/${NEW_RULE}/prometheus.yaml
```
verify that new rules are working as intended
```
promtool test rules build/kube-prometheus/mixins/${NEW_RULE}/{TEST_FILE}.yaml
```

this file is just for testing and verification, the actual rule is setup in kubeaid-config-{customerid} repo, which we generate using build.sh

- In the case when your mixin is supposed to trigger a Prometheus alert and <b>all you want is to test</b> whether it works, do this:

* Run the build script as described in the 'Run the build script' section above.
* Apply the newly generated YAML file in the test cluster's monitoring namespace where you want to test if the alert is triggered.

```
kubectl apply -f <path to alert rules file>.yaml -n monitoring
```

## Deleting metrics using Prometheus Admin APIs

* Port forward the prometheus server to access the UI and the api endpoints.
```
kubectl port-forward pod/prometheus-k8s-0 -n monitoring 9090:9090
```

* The web.enable-admin-api flag should be enabled. You can check this in the Prometheus UI. 
```
http://localhost:9090/rules
```
Use this [example](https://github.com/prometheus-operator/prometheus-operator/blob/bf74f41229e23da12e8a1ea571385b01fdc48bea/example/user-guides/getting-started/prometheus-pod-monitor.yaml#L13)

> Make sure to disable it after cleaning up the metric

* Delete the metrics by hitting the `/api/v1/admin/tsdb/delete_series?match[]=` endpoint.
```
curl -X POST -g 'http://localhost:9090/api/v1/admin/tsdb/delete_series?match[]=ceph_pool_metadata{job="job"}'
```
Note that this does not delete the metrics instantly. You can check [here](https://faun.pub/how-to-drop-and-delete-metrics-in-prometheus-7f5e6911fb33) for more details.

## Adding Support for Custom Dashboards in Grafana

### To add custom Grafana dashboards to Grafana via GitOps:

- Open the **Dashboard settings** from Grafana for the dashboard you want to add.
- Click on **JSON Model** on the left hand pane, and copy the JSON into a file on your kubeaid-config repo.
- Add a _folder name_ and the path to the dashboard in your cluster specific jsonnet file.
  See [example jsonnet file](./examples/kubeaid_managed.jsonnet) for details.

  ```jsonnet
  grafana_dashboards: {
    'Custom Grafana Folder': {
      'custom-dashboard.json': (import '../path/to/custom-dashboard.json'),
    },
  },
  ```

- Run the [build command](#run-the-build-script) with the path to your _cluster specific jsonnet file_ to generate the changes.
- Push the changes to your _kubeaid config_ repo and sync the changes in _kube-prometheus_ app on ArgoCD.
- The Grafana pod will restart after the ArgoCD sync and will reflect the new dashboard once you are logged in.

### To persist the changes made to a custom dashboard:

- Save the changes made to the dashboard on Grafana.
- Copy the JSON model of the dashboard from the **Dashboard Settings**.
- Paste and overwrite the `custom-dashboard.json` file in your kubeaid-config repo.
- Run the build script and merge the changes on your kubeaid-config repo.
- Sync the changes in ArgocD app (expect changes in ConfigMap k8s resource).
- The Grafana pod will restart and the dashboard changes will be persisted now.

## Jsonnet debugging

You can dump an entire object to see whats actually there, by wrapping a statement in a call to [`std.trace`](https://jsonnet.org/ref/stdlib.html#trace):

```jsonnet
dashboards+: std.trace(std.toString(CephMixin), CephMixin.grafanaDashboards),
```

You can also simply output an object to a file by adding a line to the bottom of the return value in
`common-template.jsonnet`. The below will write the contents of `mixins` to the file `debug`:

```jsonnet
+ { debug: mixins }
```

## Adding the Alertmanager secret

Use the [example config](./examples/alertmanager-config/alertmanager-main-slack.yaml) to create your own `alertmanager-main` secret.

The example file is a [templated sealed secret](https://github.com/bitnami-labs/sealed-secrets#sealedsecrets-as-templates-for-secrets)
and the only encrypted part is your slack url.
Run this command to seal the secret and pass your slack channel's url:

```console
kubectl create secret generic alertmanager-main --dry-run=client  --namespace monitoring  --from-literal=slack-url='https://your-slack-channel-url' -o yaml | kubeseal --controller-namespace system --controller-name sealed-secrets --namespace monitoring -o yaml --merge-into alertmanager-main.yaml
```

This example file (./examples/alertmanager-config/alertmanager-main.yaml) has no encryptedData, you can still generate the sealed secret with this

```console
kubectl create secret generic alertmanager-main --dry-run=client -o yaml | kubeseal --controller-namespace system --controller-name sealed-secrets --format yaml --merge-into alertmanager-main.yaml
```

# Integrate Keycloak with Grafana

## Refer - [Steps to configure grafana client on keycloak](./NOTES.md#integrate-keycloak-with-grafana)

# Reset Admin Password for Grafana in Kubernetes

![Grafana Logo](https://grafana.com/static/assets/img/grafana_logo.svg)

This guide provides instructions on how to reset the admin password for Grafana running on a Kubernetes cluster.
 The password reset command will be executed inside the Grafana container.

## Resetting the Admin Password

To reset the admin password for Grafana, follow these steps:

1. Find the Grafana Pod: Use the following command to list the pods in the "monitoring" namespace and find the Grafana pod:

    ```bash
    GrafanaPod=$(kubectl get pods -n monitoring | grep grafana | awk '{print $1}')
    ```

2. Reset the admin password: Use the following command to reset the admin password for Grafana:

    ```bash
    $ kubectl exec -it $GrafanaPod -n monitoring -- grafana-cli admin reset-admin-password <new-password>

    INFO [08-30|11:45:57] Starting Grafana                         logger=settings version= commit= branch= compiled=1970-01-01T00:00:00Z
    INFO [08-30|11:45:57] Config loaded from                       logger=settings file=/usr/share/grafana/conf/defaults.ini
    INFO [08-30|11:45:57] Config overridden from Environment variable logger=settings var="GF_PATHS_DATA=/var/lib/grafana"
    INFO [08-30|11:45:57] Config overridden from Environment variable logger=settings var="GF_PATHS_LOGS=/var/log/grafana"
    INFO [08-30|11:45:57] Config overridden from Environment variable logger=settings var="GF_PATHS_PLUGINS=/var/lib/grafana/plugins"
    INFO [08-30|11:45:57] Config overridden from Environment variable logger=settings var="GF_PATHS_PROVISIONING=/etc/grafana/provisioning"
    INFO [08-30|11:45:57] Path Home                                logger=settings path=/usr/share/grafana
    INFO [08-30|11:45:57] Path Data                                logger=settings path=/var/lib/grafana
    INFO [08-30|11:45:57] Path Logs                                logger=settings path=/var/log/grafana
    INFO [08-30|11:45:57] Path Plugins                             logger=settings path=/var/lib/grafana/plugins
    INFO [08-30|11:45:57] Path Provisioning                        logger=settings path=/etc/grafana/provisioning
    INFO [08-30|11:45:57] App mode production                      logger=settings
    INFO [08-30|11:45:57] Envelope encryption state                logger=secrets enabled=true current provider=secretKey.v1

    Admin password changed successfully ✔

    ```

3. Access Grafana with the New Password: Once the command completes successfully, you can access Grafana's web
    interface using the new admin password.
    If that doesn't work, you can try to restart the Grafana pod:

    ```bash
    kubectl delete pod $GrafanaPod -n monitoring
    ```
