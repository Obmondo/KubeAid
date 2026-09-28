# misp

MISP threat intelligence platform, vendored from
[cmu-sei/misp-helm](https://github.com/cmu-sei/misp-helm) (Carnegie Mellon SEI). The upstream
chart is not published to a Helm repository, so the chart directory is copied under
`charts/misp` at a pinned commit (see `Chart.yaml`).

## 1. What changed from upstream

The changes are kept as patch files under `patches/`, made against the upstream chart and
applied in lexical order (section 6 has the update procedure):

- `patches/0001-drop-mariadb-and-smtp-dependencies.patch`: the Bitnami `mariadb` and `smtp`
  dependencies are removed from `charts/misp/Chart.yaml`. The database comes from the
  mariadb-operator chart through `templates/mariadb.yaml`.
- `patches/0002-extraenv-hostaliases-and-env-checksum.patch`:
  `charts/misp/templates/deployment-misp.yaml` gains `extraEnv`, `hostAliases` and a
  `checksum/env` pod annotation (the pod reads its settings through `envFrom`, so without
  the checksum a values change never reaches a running pod), plus the two values.
- `env.redisPasswordSecret` (`charts/misp/templates/configmap.yaml`,
  `deployment-misp.yaml`, `deployment-modules.yaml`, `values.yaml`): with `name` set, MISP
  (`REDIS_PASSWORD`) and misp-modules (`REDIS_PW`) read the Valkey password from that
  Secret and it is left out of the `misp-env` and `misp-modules-env` ConfigMaps.
- `valkey` (the queue) stays as the upstream subchart, vendored under
  `charts/misp/charts/valkey` by `helm dependency update` together with `charts/misp/Chart.lock`.

`patches/upstream.yaml` names the git repository, the pinned commit and the repository files
that are not part of the chart (CI, tests, `.git`).

## 2. How to setup

Install the mariadb-operator chart first. Create three sealed Secrets in the namespace:

| Secret | Type | Keys |
|---|---|---|
| `mysql-credentials` | kubernetes.io/basic-auth | `username`, `password` (used by MISP and the MariaDB resource) |
| `oidc-credentials` | kubernetes.io/basic-auth | `username` = client id, `password` = client secret |
| `misp-api-key` | Opaque | `key` |
| `misp-redis` | Opaque | `password` (the Valkey password, see below) |

Then:

```yaml
misp:
  instanceEnv:
    mispBaseurl: https://misp.example.com
    ingressHostName: misp.example.com
  env:
    # MISP and misp-modules read the Valkey password from this Secret, so it is in
    # neither the values nor a ConfigMap.
    redisPasswordSecret:
      name: misp-redis
      key: password
  valkey:
    auth:
      usersExistingSecret: misp-redis
      aclUsers:
        default:
          passwordKey: password
          password: ""        # drop the wrapper's inline default
  misp:
    misp:
      image:
        tag: v2.5.44        # pin, upstream default is latest
```

## 3. SSO

The upstream ConfigMap carries the OIDC basics (`env.oidcEnable`, `env.oidcProviderUrl`,
`env.oidcRolesProperty`, `env.oidcRolesMapping`, `env.oidcDefaultOrg`, `env.oidcLogoutUrl`),
and the client id and secret come from `oidc-credentials`. What the image reads is decided by
`/configure_misp.sh` (`set_up_oidc`) in misp-core, not by the chart; check it after a version
bump. Two upstream keys are dead in misp-core 2.5.44: `OIDC_AUTHENTICATION_METHOD` (the image
reads `OIDC_AUTH_METHOD`, default `client_secret_post`) and `OIDC_OFFLINE_ACCESS`. Settings the
ConfigMap does not expose go through `extraEnv`:

```yaml
misp:
  env:
    oidcEnable: true
    oidcProviderUrl: https://sso.example.com/auth/realms/<realm>
    oidcRolesProperty: roles
    # first match wins; values are MISP role names or ids
    oidcRolesMapping: '{"administrator": "admin", "analyst": "User"}'
    # used when the token carries no `organization` claim; an id survives an org rename
    oidcDefaultOrg: "1"
    oidcLogoutUrl: https://sso.example.com/auth/realms/<realm>/protocol/openid-connect/logout?client_id=misp
    oidcScopes: '["openid", "email", "profile"]'
  extraEnv:
    # keep the local login form (break-glass admin) next to the SSO button
    - name: OIDC_MIXEDAUTH
      value: "true"
```

On the IdP side MISP needs `email` and a `roles` claim in the ID token or userinfo; Keycloak
puts realm roles under `realm_access.roles` by default, so add a "User Realm Role" mapper
with claim name `roles`, multivalued. The redirect URI is `<baseurl>/users/login`. A user
whose roles match nothing in the mapping is refused (and blocked if the account exists).

API key calls do not go through OIDC, so key-based automation keeps working.

If the IdP's public hostname resolves inside the cluster to an address that does not serve it
(for example an IdP published only on an internal ingress), MISP's back-channel calls fail;
pin it with `hostAliases` to the internal ingress Service IP.

## 4. Adding data

A fresh install is empty: no events, no attributes, and two feed definitions (CIRCL OSINT
and Botvrij.eu) that ship disabled. 162 further definitions sit unloaded in
`app/files/feed-metadata/defaults.json`.

**MISP 2.5 removed the feed CLI.** `cake server` exposes only `fetchIndex`, so there is no
`cake Server fetchFeed` any more. Everything below is the REST API, which mirrors the GUI
under *Sync Actions -> Feeds*. The action names below are the public methods of
`/var/www/MISP/app/Controller/FeedsController.php` inside the image: `loadDefaultFeeds`,
`index`, `enable`, `disable`, `fetchFromFeed`, `fetchFromAllFeeds`, `cacheFeeds`,
`importFeeds`. Check them there after a version bump rather than trusting this list.

Two prerequisites, or fetches silently never finish:

- **Background workers must be running.** Feed fetches are queued jobs, not synchronous
  calls. Check with `kubectl -n <ns> exec deploy/misp -- ps aux | grep start_worker` — you
  want several `start_worker default` processes.
- **The pod needs egress to the feed hosts.** Verify one:
  `kubectl -n <ns> exec deploy/misp -- curl -sI https://www.circl.lu/doc/misp/feed-osint/manifest.json`

Set up the API key created in section 2:

```bash
export KEY=$(kubectl -n <ns> get secret misp-api-key -o jsonpath='{.data.key}' | base64 -d)
export MISP=https://misp.example.com

misp_api() {
  curl -s -H "Authorization: $KEY" \
       -H "Accept: application/json" \
       -H "Content-Type: application/json" "$@"
}
```

Confirm the key works before going further - a wrong key returns 403 as HTML, not JSON:

```bash
misp_api $MISP/servers/getVersion
```

### 4.1 OSINT feeds (bulk indicators)

```bash
# list what is defined, with ids and enabled state
misp_api $MISP/feeds/index

# load the other 162 definitions first, if you want more than the two built-ins
misp_api -X POST $MISP/feeds/loadDefaultFeeds

# enable by id, then pull
misp_api -X POST $MISP/feeds/enable/1
misp_api -X POST $MISP/feeds/fetchFromAllFeeds

# watch the queued jobs
misp_api $MISP/jobs/index
```

CIRCL OSINT is a few thousand events; the first pull takes a while.

### 4.2 Feed caching (correlation without importing)

`cacheFeeds` builds the lookup index instead of creating events, so attributes correlate
against feed content that was never imported. Cheaper than a full fetch, and the right
choice when you only want hits, not a copy of every feed:

```bash
misp_api -X POST $MISP/feeds/cacheFeeds/all
```

### 4.3 Your own events

Feed data is uncontrolled. For a demo or a test you want an indicator you can guarantee
something will hit — for example the hash of a file you placed on an endpoint yourself:

```bash
cat > event.json <<'JSON'
{"Event":{"info":"Controlled test indicators",
"distribution":"0","threat_level_id":"2","analysis":"2",
"Attribute":[
 {"type":"sha256","category":"Payload delivery","to_ids":true,"value":"<hash>"},
 {"type":"ip-dst","category":"Network activity","to_ids":true,"value":"198.51.100.23"},
 {"type":"domain","category":"Network activity","to_ids":true,"value":"malicious.test"}
]}}
JSON

misp_api -X POST --data @event.json $MISP/events/add
```

### 4.4 Importing MISP JSON files

The one data path still on the CLI, for events exported from another instance:

```bash
kubectl -n <ns> exec deploy/misp -- \
  su -s /bin/sh www-data -c 'cd /var/www/MISP/app && ./Console/cake event import <file>'
```

### 4.5 Before exposing it

A fresh database contains exactly one user, `admin@admin.test`, with the MISP default
password. `instanceEnv.mispEmail` sets `MISP.email` only; it does not create or rename the
admin account. Change the password at first login.

## 5. Feeding Wazuh

Wazuh 4.14 ships an IoC rule pack, `ruleset/rules/0999-malicious-ioc-rules.xml` (rules
99901-99920): FIM hashes, source IPs across sshd, web, apache, dovecot, sqlserver, suricata
and Windows logons, and suricata DNS/HTTP domains. The rules point at three list files under
`etc/lists/malicious-ioc/` that nothing fills, so out of the box analysisd logs
`List ... could not be loaded. Rule '9990x' will be ignored` for all twenty and moves on.

`wazuhCdbExport` fills those lists from MISP. Every tick it pulls actionable attributes
(`to_ids=1`, not deleted, not on a warninglist), writes each list with
`PUT /lists/files/{name}` on the manager API and calls `PUT /cluster/analysisd/reload`, so the
content is live on every node without a restart. Expiry needs nothing extra: whatever MISP
decays or un-flags drops out of the next export.

```yaml
wazuhCdbExport:
  enabled: true
  wazuh:
    url: https://wazuh.<wazuh namespace>.svc.cluster.local:55000
    credentialsSecret: wazuh-api-cred   # sealed copy of the Wazuh chart's Secret, keys API_USERNAME / API_PASSWORD
```

The API user needs `lists:update` and `cluster:restart`; the chart's default `wazuh-wui`
(administrator) has both.

On the MISP side the export only reads. By default it uses the site admin key
(`misp.apiKeySecret`); set `wazuhCdbExport.misp.readOnlyKeySecret` to a Secret holding the
auth key of a user in the stock `Read Only` role and the job uses that instead, falling
back to the admin key while the Secret does not exist (the job log names the kind of key).
The security-operations umbrella's reconciler creates that user and Secret
(`mispReadOnly`).

With one Wazuh per tenant (Wazuh chart README section 11), list every manager in
`wazuhCdbExport.targets` instead of `wazuh`. MISP is queried once per run and each manager
gets the same lists; one failing manager does not stop the others, but fails the job:

```yaml
wazuhCdbExport:
  enabled: true
  caSecret: soc-ca-trust   # ca.crt of the CA that issued the managers' API certificates
  targets:
    - name: "001"
      url: https://wazuh.wazuh-001.svc:55000
      credentialsSecret: wazuh-api-cred-001   # copy of that tenant's API Secret, in this namespace
```

The manager API's certificate is verified. By default the Wazuh image presents a
self-signed one (`CN=wazuh.com`) that cannot be; give the manager a certificate from a
cluster CA with the Wazuh chart's `wazuh.managerTls.enabled` and point `caSecret` at a
Secret in this namespace that holds that CA's `ca.crt` (the security-operations chart does
both). `verifyTls: false` on a target (or `wazuh.verifyTls: false`) turns verification off
explicitly.

### 5.1 The Wazuh side

Three things in the Wazuh chart's values, all through hooks it already has. First, the API's
filename format is `^[-\w]+$`, so the export cannot write into the `malicious-ioc/`
subdirectory the stock rules reference; the lists are flat and must be registered:

```yaml
wazuh:
  wazuh:
    master:
      extraConf: &misp-lists |
        <ruleset>
          <list>etc/lists/misp-malware-hashes</list>
          <list>etc/lists/misp-malicious-ip</list>
          <list>etc/lists/misp-malicious-domains</list>
        </ruleset>
    worker:
      extraConf: *misp-lists
```

Second, the stock rules are re-pointed at those names by overriding them in
`wazuh.localRules` with `overwrite="yes"` - the same twenty rules, same fields, same levels,
only the list paths change. Generate the file from the pack in the image rather than by hand:

```bash
kubectl -n <ns> exec wazuh-manager-master-0 -c wazuh-manager -- \
  cat /var/ossec/ruleset/rules/0999-malicious-ioc-rules.xml \
  | sed -e 's#etc/lists/malicious-ioc/malware-hashes#etc/lists/misp-malware-hashes#' \
        -e 's#etc/lists/malicious-ioc/malicious-ip#etc/lists/misp-malicious-ip#' \
        -e 's#etc/lists/malicious-ioc/malicious-domains#etc/lists/misp-malicious-domains#' \
        -e 's#<rule id="\([0-9]*\)" level="\([0-9]*\)">#<rule id="\1" level="\2" overwrite="yes">#'
```

Third, the manager's NetworkPolicy admits the API port only from the dashboard and agent
pods; the exporter needs an ingress rule on the master (the CronJob pods carry
`app.kubernetes.io/name: misp-wazuh-cdb-export`):

```yaml
wazuh:
  wazuh:
    master:
      networkPolicy:
        extraIngresses:
          - ports: [{protocol: TCP, port: 55000}]
            from:
              - namespaceSelector:
                  matchLabels:
                    kubernetes.io/metadata.name: <misp namespace>
                podSelector:
                  matchLabels:
                    app.kubernetes.io/name: misp-wazuh-cdb-export
```

Registering the lists is a one-time restart of the managers (the chart rolls them on the
config checksum). Until the first export has run, analysisd warns that the lists are missing
and ignores the twenty rules - a warning, not a failure, verified with `wazuh-analysisd -t`.

### 5.2 Two sharp edges

`validate_cdb_list` rejects the **whole file** on the first line that fails its regex, and a
key or value containing `:` must be quoted - so a single IPv6 indicator costs the entire
list. The exporter quotes those keys and drops anything it cannot represent, reporting the
count.

The API answers **200 even when it refuses the file**; the failure is in the body as
`error != 0` with the detail in `failed_items`. Checking only the status code loses a list
without a word in any log - the API access log still shows `200`. The exporter parses the
body.

### 5.3 Checking it works

```bash
kubectl -n <misp ns> create job --from=cronjob/misp-wazuh-cdb-export export-now
kubectl -n <misp ns> logs job/export-now
# on the manager
kubectl -n <wazuh ns> exec wazuh-manager-master-0 -c wazuh-manager -- wc -l /var/ossec/etc/lists/misp-malicious-ip
```

Then put a listed hash on a monitored host (or ssh from a listed IP) and expect rule 99901
(level 14) or 99903/99904 in the alerts.

## 6. Backups and replication

`externalMariadb.backup` renders a mariadb-operator `Backup` with a schedule: the operator
dumps the database into the storage below every night and prunes what is older than
`maxRetention`. It is off, and the S3 block is a placeholder, until a bucket exists.

```yaml
externalMariadb:
  backup:
    enabled: true
    schedule: "0 2 * * *"
    maxRetention: 720h
    storage:
      type: S3           # or PersistentVolumeClaim
      s3:
        bucket: kubesoc-backups
        prefix: kubesoc/misp-mariadb
        endpoint: s3.example.com:443   # host:port, not a URL; empty means AWS S3
        credentialsSecret: kubesoc-backup-s3
```

The attachments live on a separate ReadWriteOnce volume
(`misp.pvc.attachments.storageRequest`) and are **not** in the dump: back that volume up with
Velero (the security-operations chart's `backup.velero` covers this namespace). A database
dump without the attachments restores an instance whose events have no files.

`kubeaid-cli siem backup` clones this `Backup` without its schedule for a backup out of band,
and `siem restore` turns each `Backup` of a set into a mariadb-operator `Restore`; both find
it through `spec.mariaDbRef`, so the storage and credentials only have to be right here.

`externalMariadb.replicas` above 1 turns on the operator's asynchronous replication: one
primary and the rest replicas, `waitPoint: AfterSync` so a failover cannot lose a committed
event, automatic failover, and a `PodDisruptionBudget`. MISP keeps writing to the primary
through the Service the operator repoints. Each replica needs its own volume, so the
StorageClass must have the capacity; `externalMariadb.topologyKey` spreads them over failure
domains. MISP itself stays a single replica: its attachments volume is ReadWriteOnce.

## 7. Updating

The chart is a `file://` dependency, so `bin/manage-helm-chart.sh` never replaces it, and
`.helm-update-skip` keeps it out of the weekly `--update-all` run all the same. Update it by
hand from this directory (`argocd-helm-charts/misp`):

```bash
here=$PWD; tmp=$(mktemp -d)
git clone https://github.com/cmu-sei/misp-helm "$tmp/src" && git -C "$tmp/src" checkout <commit>
cp -R "$tmp/src" "$tmp/a"
(cd "$tmp/a" && rm -rf .checkov.yaml .git .github .gitignore Makefile README.md.gotmpl ci ct.yaml tests)
cp -R "$tmp/a" "$tmp/b"
for p in "$here"/patches/*.patch; do patch -d "$tmp/b" -p1 < "$p"; done
```

If a patch fails, keep a copy of the tree from just before it (`cp -R "$tmp/b" "$tmp/before"`),
apply it with `--fuzz=3`, fix the `*.rej` hunks in `$tmp/b` by hand (then delete the `*.rej`
and `*.orig` files), regenerate it with
`cd "$tmp" && git diff --no-index --src-prefix= --dst-prefix= before b > "$here/patches/<patch>"`
and go on with the next patch. Then install the new copy:

```bash
rm -rf charts/misp && cp -R "$tmp/b" charts/misp
helm dependency update charts/misp
tar -C charts/misp/charts -xf charts/misp/charts/valkey-*.tgz && rm charts/misp/charts/*.tgz
```

Set the new commit as `ref` in `patches/upstream.yaml` and in the `Chart.yaml` comment, and
the chart version in `Chart.yaml` if it changed. `helm dependency update .` refreshes
`Chart.lock`. Then, on Linux, `bin/manage-helm-chart.sh --verify-patches misp` (from the
repository root) clones the pinned commit, applies the patches, rebuilds `valkey` from
`charts/misp/Chart.lock` and diffs the result against `charts/misp`; it exits non-zero on
any difference. A new KubeAid change to `charts/misp` goes into a patch file the same way.
