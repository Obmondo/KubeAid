# kubesoc-content

Detection content as code for the kubesoc security operations stack: Wazuh rules,
decoders, CDB lists and agent group configs, Velociraptor artifacts and AI prompts, with
test fixtures and a version. The chart renders all of it into one ConfigMap,
`kubesoc-content`; the `siem-reconciler` (security-operations chart) mounts it and rolls it
out to the running tools. Nothing here restarts a pod.

It is a dependency of the `security-operations` umbrella, off by default:

```yaml
# security-operations values
kubesoc-content:
  enabled: true
  canary: "001"               # tenant rolled out first; empty = the first tenant
  velociraptorArtifacts: true # set artifacts with artifact_set (see below)
velociraptor:
  velociraptor:
    customArtifacts:
      enabled: false          # required with velociraptorArtifacts (render check)
```

and every tenant Wazuh (`argocd-helm-charts/kubesoc/wazuh`) registers the lists and excludes the
stock IoC file in its `<ruleset>` (KubeAid patch, wazuh README "Local patches"):

```yaml
wazuh:
  wazuh:
    ruleset:
      extraLists:
        - etc/lists/misp-malware-hashes
        - etc/lists/misp-malicious-ip
        - etc/lists/misp-malicious-domains
      extraRuleExcludes:
        - 0999-malicious-ioc-rules.xml
```

kubeaid-cli renders both when `cluster.securityOperations.content.enabled` is true, and
then stops rendering `wazuh.localRules` and the hand-copied `<ruleset>` in each tenant's
`master.extraConf`.

## Layout

| Path | What | Goes to |
|---|---|---|
| `VERSION` | Content version (semver). Bump it with every change. | ConfigMap label, state Secrets, report |
| `wazuh/rules/*.xml` | Rule files. `kubesoc-0999-malicious-ioc.xml` is Wazuh 4.14's IoC pack (99901-99920) re-pointed at the MISP-fed lists. | every tenant manager, `etc/rules/` |
| `wazuh/decoders/*.xml` | Decoder files. | `etc/decoders/` |
| `wazuh/lists/<name>` | Static CDB lists (`key:value` lines; names `^[-\w]+$`). The MISP-fed lists stay dynamic (misp chart `wazuhCdbExport`). | `etc/lists/` |
| `wazuh/agent-groups/<group>/agent.conf` | Agent group configs. | `etc/shared/<group>/agent.conf` |
| `velociraptor/artifacts/*.yaml` | Velociraptor artifacts. security-operations `files/velociraptor/*.yaml` are rolled out with them. | the server's datastore (`artifact_set`) |
| `ai/prompts/*` | Prompts. `triage-system.txt` is the IRIS triage prompt (`TRIAGE_SYSTEM_PROMPT_FILE` in `ai-triage.py`). | mounted by the consumer |
| `tenants/<code>/wazuh/...` | Files for one tenant only, same layout as `wazuh/`; a file with a shared file's name replaces it for that tenant. | that tenant's manager |
| `tests/<name>/` | Fixtures: `input.log` (one event per line) and `expected.json`. `tests/pending/` holds fixtures nobody has replayed yet; CI ignores them. | CI |

`local_rules.xml` and `local_decoder.xml` belong to the wazuh chart (rewritten at every
start) and are refused here. Name files `kubesoc-*` so they never shadow a stock file.

Per-tenant selection is values-driven:

```yaml
kubesoc-content:
  exclude: [wazuh/rules/kubesoc-noisy.xml]       # nobody gets it
  optional: [wazuh/agent-groups/kubesoc-linux-baseline/agent.conf]  # only who includes it
  tenants:
    "001":
      include: [wazuh/agent-groups/kubesoc-linux-baseline/agent.conf]
      exclude: [wazuh/rules/kubesoc-0999-malicious-ioc.xml]
```

## How a change reaches the tenants

1. A pull request changes files here and bumps `VERSION`. The `kubesoc content` workflow
   (`.github/workflows/kubesoc-content.yml`) runs `tests/lint.sh` (XML, duplicate rule ids,
   list format, fixture schema), `tests/logtest.sh` (every fixture through `wazuh-logtest`
   in `wazuh/wazuh-manager:4.14.3`), `tests/velociraptor_verify.sh`
   (`velociraptor artifacts verify` on every artifact), pytest for the SOC scripts and the
   render tests of this chart, wazuh and security-operations.
2. After merge, Argo CD syncs security-operations: ConfigMap `kubesoc-content` changes.
   No pod restarts.
3. The reconciler (Sync hook, PostSync hook, then every schedule tick) loads the package
   and, for each tenant manager, **canary first**:
   - reads each file from the manager and uploads what differs
     (`PUT /{rules,decoders,lists}/files/{name}?overwrite=true`; the API refuses malformed
     XML), deleting files the previous version owned and this one does not;
   - checks `GET /manager/configuration/validation` and hot-reloads analysisd
     (`PUT /cluster/analysisd/reload`); any error, or a reload warning the old content did
     not produce (unknown `if_sid`, duplicate id, ...), **rolls back**: every touched file
     goes back to the last good content, and analysisd reloads again;
   - writes agent group configs (group created if missing; never deleted);
   - records the version in Secret `kubesoc-content-wazuh-<code>` (gzipped last good files,
     label `kubesoc.io/content-version`).
   If the canary fails, the other tenants are reported `skip` and keep their content.
   Then it sets changed Velociraptor artifacts with `artifact_set()` and reads them back
   (Secret `kubesoc-content-velociraptor`).
4. The job log is the report (`content/<code>` and `content/velociraptor` rows); with
   `reconciler.dryRun: true` it only plans.

A new static list additionally needs its `etc/lists/<name>` in `wazuh.ruleset.extraLists`
(kubeaid-cli: `securityOperations.content.extraLists`): registering a list changes
`ossec.conf` and restarts the manager, which the chart does. The reconciler reports a
content list the manager has not registered as an error and uploads nothing to it.

## Write a rule

1. Add or edit `wazuh/rules/kubesoc-<topic>.xml`. Use ids 100000-120000 for new rules
   (99901-99920 are the IoC pack). Keep one `<group>` per topic.
2. Add a fixture `tests/<rule-id>/` with a real (sanitised) event in `input.log` and

   ```json
   {"rule_id": "100200", "level": 10, "decoder": "sshd"}
   ```

   Add `"location": "EventChannel"` for events that need a location. Add a negative fixture
   (`tests/<rule-id>-benign/`, expecting the parent rule) when a lookup or match should not
   fire. Test-only list content for lists the package does not ship goes in `tests/lists/`.
   Keep the fixture in `tests/pending/<rule-id>/` until `tests/logtest.sh` has replayed it
   (the parent rule's decoder and level are easy to get wrong from reading alone), then move
   it up one level: CI only runs what sits directly under `tests/`.
3. Bump `VERSION`.

## Test locally

```sh
cd argocd-helm-charts/kubesoc/kubesoc-content
tests/lint.sh                 # xmllint, python3
tests/render_test.sh          # helm, yq
tests/logtest.sh              # docker; KEEP=1 keeps the container for poking
tests/velociraptor_verify.sh  # docker
```

`KEEP=1 tests/logtest.sh`, then
`docker exec -it <container> /var/ossec/bin/wazuh-logtest` to paste events by hand.

Against a live manager without the reconciler image, a checkout works as the package:
`siem-reconciler --config tenants.json --only content --dry-run` with
`components.content.dir` pointing at this directory.

## Release

Merge to the branch the clusters track (`securityOperations.chartRevision`). Roll out to one
tenant first by setting `canary`; watch the job log or
`kubectl -n security-operations get secret -l kubesoc.io/content-target -L kubesoc.io/content-version`.
To roll back, revert the commit: the reconciler brings every manager back to the reverted
content the same way.

## Limits

- One ConfigMap: the render fails above `maxBytes` (900 kB).
- Removing an agent group from the package leaves the group on the manager.
- Artifacts the server loaded from its definitions directory are built in and cannot be
  replaced by `artifact_set`; keep `customArtifacts` off while `velociraptorArtifacts` is on.
- First enable: the manager restarts with the new `<ruleset>` and without the IoC rules in
  `local_rules.xml`; they are back once the reconciler's next run uploads them.
