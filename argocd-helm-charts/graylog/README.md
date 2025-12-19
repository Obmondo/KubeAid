# Graylog docs

## Add the graylog username and password into sealed secret

```sh
# pwgen 20 1 | tr -d '\n' > graylog-password
# cat graylog-password | sha256sum | tr -d '\n' > graylog-sha2
# kubectl create secret generic graylog -n graylog  --dry-run=client --from-file=graylog-password-secret=./graylog-password --from-file=graylog-password-sha2=./graylog-sha2 -o json >graylog.json
# kubeseal --controller-name sealed-secrets-controller --controller-namespace sealed-secrets < graylog.json > graylog-final.json
```

**TODO:** Add infomation about creating the graylog-es-svc secret

## Port forwarding to access the Graylog

**Note: this is handy when authentication via header is enabled.**

```sh
kubectl port-forward -n graylog svc/graylog 9091:9000
```

## set admin password (in standalone setup)

Helm chart takes care of converting the password into `sha256` hash. [configure](https://docs.graylog.org/en/4.0/pages/getting_started/configure.html)

```sh
echo -n "Enter Password: " && head -1 </dev/stdin | tr -d '\n' | sha256sum | cut -d" " -f1
```

Push this new string out in graylog secret - key graylog-password-sha2

## Beats input

To create Beats input, go to the web interface:

* Go to the inputs page (Menu bar->System->Inputs)
* In the "Select input" drop down menu, select "Beats"
* Click "Launch new input"
* Enter the following in the form:
  * Title: Beats
  * Port: 5044
  * Enable the "Do not add Beats type as prefix" option, at the bottom
* Click "Save"

## Index and log retention configuration

* Go to the "Configure Index Set" page (Menu bar->System->Indices)
* Click the `edit` button, next to the "Default index set"
* In the "Index Rotation Configuration" section
  * Select rotation strategy: `Index Time`
  * Rotation period: `P1D`
* In the "Index Retention Configuration" section
  * Select retention strategy: `Delete Index`
  * Max number of indices: `180`

## trigger index cycle now (instead of at night)

```sh
curl -XPOST http://127.0.0.1:9000/api/system/deflector/cycle -H 'X-Requested-By: localhost'
```

login (user+password) can be found in secret called graylog - field `data.graylog-password-secret`

## Connecting MongoDB

Graylog needs to connect to MongoDB to store configs. This chart uses the MongoDB operator to
add a database by creating an object of `kind: MongoDBCommunity`.

The object also tells the operator to create a separate `graylog` database
and a `graylog-user` with `readWrite` permissions. It expects a secret `graylog-user-password`
containing the password which will be used by graylog client later.

The connection string for the graylog client is generated and kept in a secret
called `mongodb-replica-set-graylog-graylog-user`. The string is of the form :

```bash
mongodb://graylog-user:<password>@mongodb-replica-set-0.mongodb-replica-set-svc.graylog.svc.cluster.local:27017/graylog?replicaSet=mongodb-replica-set&ssl=false
```

This username and password combination allows the Graylog client to authenticate itself to the MongoDB instance.

**NOTE: Do not use `userAdminAnyDatabase` role of MongoDB as it does not have permissions to create index.**

Create the mongodb graylog-user password

```bash
kubectl create secret generic graylog-user-password -n default --dry-run=client --from-literal=password=lolpassword -o yaml
```

## Opensearch (elasticsearch fork with open source license)

```bash
kubectl create secret generic graylog-es-svc -n graylog --from-literal=url='http://admin:admin@opensearch-cluster-master:9200' -o yaml
```

## Upgrade Instruction

Graylog and OpenSearch are both under active development. This means that new versions are released
frequently. This guide will help you upgrade your Graylog and OpenSearch installation to the
latest version.

* Check the graylog interoperability chart to see which version of Graylog is compatible with the
version of OpenSearch and mongodb you are upgrading to.
https://go2docs.graylog.org/5-0/planning_your_deployment/planning_your_upgrade_to_opensearch.htm

### 1. Upgrading MongoDB

* Take a backup of the mongodb by running the backup job manually.

    ```bash
    kubectl create job --from=cronjob/mongodb-backup manual-backup -n graylog
    ```

* In the graylog application Sync the mongodb-community crd changes first as the MongoDb v5.0
  is not compatible with graylog v4.3.9.
* Expect graylog to go down during the upgrade process.

### 2. Upgrading Graylog

* Sync the graylog application in the argocd.
* Wait for the graylog pods to be in running state.
* Check the logs
* Check the graylog UI for any errors.

### 3. Upgrading OpenSearch

* Take a snapshot

    ```bash
    kubectl create job --from=cronjob/opensearch-s3-snapshot-create manual-snapshot -n graylog
    ```

* Sync the opensearch application in the argocd.
* Wait for the opensearch pods to be in running state.
* opensearch cluster are not downgradable, so please restore it from snapshot (look at opensearch helm chart readme)

## Backup and Restore

[Documentation can be found here](../mongodb-operator/Readme.md#backup-and-restore)
