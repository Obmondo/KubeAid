# dfir-iris

[DFIR-IRIS](https://github.com/dfir-iris/iris-web) collaborative incident response platform
(LGPL-3.0). This is a KubeAid-authored chart: the upstream `deploy/kubernetes` chart is an
unmaintained template with placeholder values that bundles PostgreSQL and RabbitMQ as raw
containers, so it is not wrapped. This chart runs the official `iriswebapp_app` image as the
app and the Celery worker, and takes PostgreSQL (CNPG) and RabbitMQ from kubeaid-addons.
The upstream nginx container is not used; TLS terminates at the ingress.

## 1. How to setup

Install cloudnative-pg and rabbitmq-operator first. Create one sealed Secret named
`dfir-iris` with the keys `IRIS_SECRET_KEY`, `IRIS_SECURITY_PASSWORD_SALT` and
`IRIS_ADM_PASSWORD` (random strings). Then:

```yaml
ingress:
  enabled: true
  host: iris.example.com
  tls:
    - secretName: iris-tls
      hosts:
        - iris.example.com
admin:
  email: soc@example.com
```

The first start creates the database schema and the administrator account from
`IRIS_ADM_*`. Database credentials are read from the CNPG-generated
`iris-pgsql-app` Secret and the broker credentials from `iris-rabbitmq-default-user`.

## 2. Storage

Downloads, user templates and server data live on one PVC mounted by both the app and the
worker. With ReadWriteOnce the worker is scheduled onto the app's node; use a ReadWriteMany
class (CephFS) to remove that constraint.

## 3. Known assumptions

- IRIS is given the same role for `POSTGRES_USER` (which it uses to create the database) and
  `POSTGRES_ADMIN_USER` (runtime). CNPG already creates `iris_db` owned by that role, so the
  create step should be skipped. Not yet verified on a cluster; confirm on the first deploy
  and, if the entrypoint insists on a superuser, point `postgres.existingSecret` at the CNPG
  superuser Secret instead.
- The `/login` readiness probe works with every authentication type: with OIDC and
  `localFallback: false` it answers with a redirect, which the probe counts as ready.

## 4. SSO (OIDC)

IRIS 2.4 has one authentication type at a time (`local`, `ldap` or `oidc`). With `oidc`
the login page shows a "Use SSO" button; `localFallback: true` keeps the username/password
form beside it, which is the break-glass path for the local administrator.

```yaml
authentication:
  type: oidc
  localFallback: true
  createUserIfNotExist: false
  oidc:
    issuerUrl: https://keycloak.example.com/auth/realms/myrealm
    clientId: iris
    existingSecret: dfir-iris-oidc   # key OIDC_CLIENT_SECRET
```

On the identity provider, create a confidential client with the standard (authorization
code) flow, redirect URI `https://<ingress.host>/oidc-authorize`, and the `profile` and
`email` scopes so the ID token carries `preferred_username` and `email`. IRIS reads the
discovery document from `issuerUrl` at startup, so the pods must reach that URL; if the
hostname resolves to an address the pods cannot use, add a `hostAliases` entry.

What IRIS does and does not do (checked against the 2.4.20 source):

- Users are matched on the username claim (`oidc.mappingUsername`, falling back to the
  `mappingEmail` claim when it is missing) against IRIS logins, including existing local
  and service accounts. With the default `preferred_username` an IdP user named
  `administrator` signs in as the local administrator; set `mappingUsername: sub` (the
  IdP's immutable user id) or `email` so no IdP user can match a local login. The
  security-operations umbrella uses `sub` and `localFallback: false`.
- With `createUserIfNotExist: true` a first login creates the user in the default
  organisation only: no group, no customer, no permissions. With `false` an administrator
  pre-creates the user (login equal to the username claim) and gets a 404 page otherwise.
  `IRIS_NEW_USERS_DEFAULT_GROUP` applies to LDAP only.
- Groups and roles are not mapped from the token; assign groups and customers in
  Manage > Users by hand.
- API keys (`Authorization: Bearer` or `X-IRIS-AUTH`) are checked independently of the
  authentication type, so integrations keep working.
- MFA enforcement is skipped for OIDC logins.

## Access from Keycloak roles and groups (`keycloakSync`)

IRIS's OIDC login reads only the username and email claims, so a user who signs
in through SSO lands with no group and no customer. The optional
`keycloakSync` CronJob closes that gap: every few minutes it reads realm roles
and groups from Keycloak and sets each user's IRIS groups and customers to
exactly what `keycloakSync.mapping` yields.

- Missing users are created (random unused password) and activated, so they are
  ready before their first login. Their login is the Keycloak attribute behind
  the claim IRIS's OIDC login matches (`authentication.oidc.mappingUsername`):
  the username for `preferred_username`, the e-mail for `email`, the user id for
  `sub`.
- With `preferred_username`, any IdP user whose username equals a local IRIS
  login signs in as that account. `sub` (or `email`) closes that: a local login
  such as `administrator` can never equal a Keycloak user id. Switching an
  existing install renames each user the sync created earlier (login = username)
  to the new login when its IRIS e-mail equals the Keycloak e-mail, so cases and
  history stay with it; any other IRIS user with the old login is deactivated as
  an orphan and the user is created anew.
- Access removed in Keycloak is removed in IRIS on the next run. A user whose
  mapping yields no group or no customer, or who is disabled or deleted in
  Keycloak, is deactivated.
- Only the groups the mapping names are managed; other groups a user was given
  by hand stay. Customers are set exactly.
- Service accounts and `protectedLogins` (plus `admin.username`) are never
  touched. A Keycloak user with a protected name is reported and skipped,
  because an SSO login with that name would sign in as the local account.
- `dryRun: true` (the default) only logs what it would change. Read the job log,
  then set it to false.
- `keycloakSync.mappingConfigMap.name` reads the mapping from a ConfigMap managed
  elsewhere (same JSON shape, key `mappingConfigMap.key`) instead of
  `keycloakSync.mapping`. The security-operations umbrella chart uses it to
  render one entry per tenant. The file is read on every run.

Prerequisites: a confidential Keycloak client with a service account holding
`realm-management` `view-users`, and the API key of an IRIS user with
`server_administrator`, both in `keycloakSync.existingSecret`. If the Keycloak
hostname does not resolve correctly inside the cluster, set `hostAliases`; the
job uses the same entries as the app.

## AI assistant with a self-hosted model (`aiTriage`)

One CronJob (`<fullname>-ai-triage`) runs `files/ai/ai_assist.py` with the enabled
modes, in turn, against a local Ollama model (default `mistral:7b`, Apache-2.0; on a
GPU node `mistral-small3.1`, see the ollama chart README). Nothing leaves the cluster.

| Mode | Switch | Trigger | Output |
|---|---|---|---|
| Alert triage | `triage.enabled` (on) | New alert without an `ai:` tag | Appended to the alert note: severity, false-positive likelihood, category, summary, next step, ATT&CK techniques. Tags `ai:triaged`, `ai:sev:<level>`, `ai:fp:<likely\|unlikely\|unknown>`, `ai:attack:<Txxxx>` (`ai:error` on failure) |
| Case summary / report draft | `caseSummary.enabled` | Case tag `ai:summarize`; with `onClose`, any case closed in the last `lookbackDays` | Note "AI draft - incident summary and report" in directory `AI drafts`: executive summary, impact, timeline, affected assets and indicators (copied from the case record, not retyped by the model), ATT&CK, recommended actions, open questions. Tag becomes `ai:summarized` (`ai:summarize:error` on failure) |
| Hunting | `hunt.enabled` | Note titled `ai:hunt: <question>` (or `ai:hunt` with the question as content) in an open case | Note "AI hunt suggestion (re note N)": a Wazuh DQL filter, an OpenSearch query DSL body, a Velociraptor VQL hunt, time range, caveats, ATT&CK. VQL calling functions that change endpoints or reach out (execve, upload, rm, http_client, ...) is flagged |

How analysts use it:

- **Triage**: nothing to do; read the AI part of the alert note and the `ai:` tags
  (filterable in the alert list).
- **Summary**: add the tag `ai:summarize` to the case. Within a few minutes the draft
  appears under Notes > AI drafts. Edit it into the real report. For a fresh draft,
  remove `ai:summarized` and add `ai:summarize` again.
- **Hunting**: add a note titled e.g. `ai:hunt: which hosts had failed SSH logins from
  the case's source IP in the last 7 days`. The answer note appears in AI drafts. Review
  each query, adapt it, and run it yourself in the Wazuh dashboard or as a Velociraptor
  hunt. Delete the answer note to ask the same question again.

Guardrails:

- **Advisory only.** The job writes notes and tags, nothing else: it never changes
  severity, status or outcome, never escalates, and never runs a query, hunt or response.
  Every AI note starts with "AI draft - review required" and names the model and the
  prompt version.
- **Untrusted input.** Alert, case and note content can be written by an attacker. It
  reaches the model JSON-encoded, with `<` and `>` escaped, between tags carrying a random
  nonce, and a fixed guard text in the system prompt (not overridable by prompt files)
  says that the data is never an instruction and that the assistant has no tools.
- **Constrained output.** Ollama's `format` JSON schema, temperature 0, a token limit per
  mode; the answer is validated again (enums, required fields, string length limits,
  ATT&CK ids must look like `T1234` or `T1234.001`). Model prose is written with markup
  escaped and links defanged (`hxxps[:]//`); queries go into code blocks they cannot close.
- **Redaction** (`redact: true`): passwords, tokens, API keys, JWTs, private keys and
  credentials in URLs are masked before the model sees them. Hashes and IPs are kept.
- **Size limits**: triage input 6000 characters, case input 16000, hunt input 8000.
- Outside the detection path: a slow or missing model never delays alerts; the job stops
  starting model calls 30 s before `activeDeadlineSeconds`.
- Unowned alerts stay unowned (IRIS would otherwise make the job their owner).

Prompts: the built-in prompts and schemas (`files/ai/kubesoc_ai.py`) can be replaced per
mode with `<mode>.system.txt` and `<mode>.schema.json` (mode `triage`, `summary`, `hunt`)
from `promptsConfigMap.name` or inline `prompts`, mounted at `PROMPTS_DIR` (`/prompts`).
The kubesoc-content package's `ai/prompts/` spelling (`<mode>-system.txt`,
`<mode>-schema.json`) is read just as well, and `<MODE>_SYSTEM_PROMPT_FILE`
(e.g. `TRIAGE_SYSTEM_PROMPT_FILE`) names one prompt file outright and wins over the
directory. A replacement schema must keep the default's fields. The note then records
`custom-<sha256 prefix>` as the prompt version, and the guard text stays either way.

Enable (the security-operations umbrella wires the URL, key and NetworkPolicy):

```yaml
aiTriage:
  enabled: true
  dryRun: true          # read the job log first, then false
  ollamaUrl: http://ollama.ollama.svc:11434
  existingSecret: iris-ai-triage
  caseSummary:
    enabled: true
  hunt:
    enabled: true
```

Network flows the job needs: egress to IRIS (`<fullname>-app`, TCP 8000) and to Ollama
(TCP 11434, which admits pods labelled `app.kubernetes.io/component: ai-triage`), plus DNS.

Tests: `python3 -m unittest discover -s argocd-helm-charts/dfir-iris/tests` (or pytest)
runs the jobs against fake IRIS, Ollama and MISP APIs.

## MISP sightings (`mispSightings`)

An optional CronJob (`<fullname>-misp-sightings`, `files/ai/misp_sightings.py`) reports
confirmed incidents back to MISP. IRIS 2.4 records a case's outcome in `status_id`
("Outcome" in the case summary): 1 false positive, 2 true positive with impact, 4 true
positive without impact (0 unknown, 3 not applicable, 5 legitimate).

- A case closed within `lookbackDays` with outcome 2 or 4 adds a sighting (type 0, source
  `sightingSource`) to every case indicator MISP already knows, then gets the tag
  `misp:sighted` (`misp:error` if MISP refused). Remove the tag to report it again.
- `createEvents: true`: indicators MISP does not know go into one new unpublished event
  per case (distribution `eventDistribution`, default 0 = your organisation, tag
  `tlp:amber`), and are sighted too. Indicators with TLP:RED in IRIS are never sent.
- `falsePositiveSightings: true`: cases closed as false positive add false-positive
  sightings (type 1) instead.

The MISP key (`misp.apiKeySecret`) must belong to a user allowed to add sightings (and
events with `createEvents`); a read-only export key is not enough. The IRIS key needs case
read and case update (tags). Flows: IRIS TCP 8000 and MISP (TCP 80 in-cluster, or 443).

```yaml
mispSightings:
  enabled: true
  dryRun: true
  misp:
    url: http://misp
    apiKeySecret: misp-sightings-key
  existingSecret: iris-ai-triage
```
