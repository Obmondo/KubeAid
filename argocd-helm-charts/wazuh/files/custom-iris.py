#!/usr/bin/env python3
"""Wazuh -> DFIR-IRIS integration.

Turns a Wazuh alert into an IRIS alert, carrying the whole original alert in
alert_source_content so the analyst has the SIEM context without going back to
the dashboard.

Invoked by wazuh-integratord as:
    custom-iris <alert_file> <api_key> <hook_url> [<options_file>]

where hook_url is the IRIS base URL and the options file (from <options> in
ossec.conf) may carry:

    {"customer_map": {"001": 2, "002": 3}, "default_customer_id": 1,
     "dashboard_url": "https://wazuh.example.com", "tenant_field": "tenant"}

The tenant is read from an agent label, so case routing follows the same
label the indices are routed by.

Two keys keep per-tenant data out of ossec.conf:

    "options_file": "/path/options.json"
        JSON object merged under the inline options (inline keys win). Read
        on every alert, so a mounted ConfigMap can change without a restart.
    "customer_names": {"001": "Tenant A"}
        tenant label -> IRIS customer name, for tenants not in customer_map.
        The id is looked up through GET /manage/customers/list, because IRIS
        assigns customer ids itself and they differ per installation.

One key serves a manager that belongs to a single tenant:

    "customer_name": "Tenant A"
        every alert of this manager goes to this IRIS customer (looked up by
        name as above). The agent label is then only used for tags.

Deliberately NOT modelled on the bundled shuffle integration: that one filters
a hardcoded SKIP_RULE_IDS list to work around Shuffle starting containers, and
it silently drops rule 80710 (auditd promiscuous mode, level 10) along with the
docker noise it is actually aimed at.
"""
import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

# IRIS severities (severities table): 3 Informational, 4 Low, 1 Medium, 5 High, 6 Critical
SEVERITY_BY_LEVEL = ((4, 3), (7, 4), (11, 1), (13, 5))
SEVERITY_MAX = 6
STATUS_NEW = 2

# IRIS ioc_type ids
IOC_TYPES = {
    "ip-src": 79, "ip-dst": 77, "sha256": 113, "md5": 90, "sha1": 111,
    "domain": 20, "hostname": 69, "filename": 37, "url": 141,
}
# IRIS assets_type ids
ASSET_LINUX, ASSET_MAC, ASSET_WINDOWS, ASSET_OTHER = 4, 6, 9, 1


def debug(msg):
    print(msg, file=sys.stderr, flush=True)


def severity_id(level):
    for ceiling, sev in SEVERITY_BY_LEVEL:
        if level <= ceiling:
            return sev
    return SEVERITY_MAX


def asset_type_id(agent):
    platform = ((agent.get("os") or {}).get("platform") or "").lower()
    uname = ((agent.get("os") or {}).get("uname") or "").lower()
    if "windows" in platform or "windows" in uname:
        return ASSET_WINDOWS
    if "darwin" in platform or "darwin" in uname:
        return ASSET_MAC
    if platform or "linux" in uname:
        return ASSET_LINUX
    return ASSET_OTHER


def collect_iocs(alert):
    """Observables worth pivoting on. Values are deduplicated by (type, value)."""
    data = alert.get("data") or {}
    syscheck = alert.get("syscheck") or {}
    found = []

    for key, ioc_type in (("srcip", "ip-src"), ("dstip", "ip-dst"),
                          ("hostname", "hostname"), ("url", "url")):
        value = data.get(key)
        if value:
            found.append((ioc_type, str(value)))

    for key, ioc_type in (("sha256_after", "sha256"), ("md5_after", "md5"),
                          ("sha1_after", "sha1")):
        value = syscheck.get(key)
        if value:
            found.append((ioc_type, str(value)))
    if syscheck.get("path"):
        found.append(("filename", str(syscheck["path"])))

    seen, iocs = set(), []
    for ioc_type, value in found:
        if (ioc_type, value) in seen:
            continue
        seen.add((ioc_type, value))
        iocs.append({
            "ioc_value": value,
            "ioc_type_id": IOC_TYPES[ioc_type],
            "ioc_description": "From Wazuh rule %s" % (alert.get("rule") or {}).get("id", "?"),
            "ioc_tlp_id": 2,  # amber
        })
    return iocs


def lookup_customer_id(hook_url, api_key, name, timeout):
    """IRIS customer id for a customer name, or None."""
    request = urllib.request.Request(
        "%s/manage/customers/list" % hook_url.rstrip("/"),
        headers={"Authorization": "Bearer %s" % api_key})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as reply:
            body = json.loads(reply.read())
    except (urllib.error.URLError, ValueError) as exc:
        debug("custom-iris: cannot list IRIS customers: %s" % exc)
        return None
    for customer in body.get("data") or []:
        if customer.get("customer_name") == name:
            return customer.get("customer_id")
    debug("custom-iris: no IRIS customer named %r" % name)
    return None


def build_alert(alert, options, resolve_customer=None):
    rule = alert.get("rule") or {}
    agent = alert.get("agent") or {}
    level = int(rule.get("level") or 0)

    tenant_field = options.get("tenant_field", "tenant")
    tenant = ((agent.get("labels") or {}).get(tenant_field)) or ""
    customer_id = None
    if options.get("customer_name") and resolve_customer:
        customer_id = resolve_customer(options["customer_name"])
    if customer_id is None:
        customer_id = options.get("customer_map", {}).get(str(tenant))
    if customer_id is None and tenant and resolve_customer:
        name = (options.get("customer_names") or {}).get(str(tenant))
        if name:
            customer_id = resolve_customer(name)
    if customer_id is None:
        customer_id = options.get("default_customer_id", 1)

    tags = ["wazuh", "rule:%s" % rule.get("id", "?"), "level:%d" % level]
    tags += [g for g in (rule.get("groups") or []) if g]
    if tenant:
        tags.append("tenant:%s" % tenant)
    if agent.get("name"):
        tags.append("agent:%s" % agent["name"])
    for technique in ((rule.get("mitre") or {}).get("id") or []):
        tags.append("mitre:%s" % technique)

    description = [
        "Wazuh rule %s (level %d) fired on agent %s (%s)." % (
            rule.get("id", "?"), level, agent.get("name", "?"), agent.get("id", "?")),
    ]
    if agent.get("ip"):
        description.append("Agent address: %s" % agent["ip"])
    if tenant:
        description.append("Tenant: %s" % tenant)
    if alert.get("full_log"):
        description.append("\n%s" % alert["full_log"][:4000])

    payload = {
        "alert_title": rule.get("description") or "Wazuh alert",
        "alert_description": "\n".join(description),
        "alert_source": "Wazuh",
        "alert_source_ref": str(alert.get("id") or ""),
        "alert_severity_id": severity_id(level),
        "alert_status_id": STATUS_NEW,
        "alert_customer_id": customer_id,
        # The whole alert travels with the case - this is what keeps an analyst
        # from having to reopen the SIEM to see what actually happened.
        "alert_source_content": alert,
        "alert_context": {
            "rule_id": rule.get("id"),
            "rule_level": level,
            "agent_name": agent.get("name"),
            "agent_id": agent.get("id"),
            "tenant": tenant,
            "location": alert.get("location"),
        },
        "alert_tags": ",".join(tags),
        "alert_iocs": collect_iocs(alert),
    }

    if alert.get("timestamp"):
        # Wazuh sends ISO8601 with a numeric offset; IRIS wants a naive UTC stamp.
        try:
            parsed = datetime.fromisoformat(alert["timestamp"])
            if parsed.tzinfo:
                parsed = parsed.astimezone(timezone.utc).replace(tzinfo=None)
            payload["alert_source_event_time"] = parsed.isoformat(timespec="seconds")
        except ValueError:
            debug("custom-iris: unparsable timestamp %r, letting IRIS default it"
                  % alert["timestamp"])

    if agent.get("name"):
        payload["alert_assets"] = [{
            "asset_name": agent["name"],
            "asset_type_id": asset_type_id(agent),
            "asset_description": "Wazuh agent %s" % agent.get("id", "?"),
            "asset_ip": agent.get("ip") or "",
            "asset_tags": "tenant:%s" % tenant if tenant else "",
        }]

    dashboard = options.get("dashboard_url")
    if dashboard and alert.get("id"):
        payload["alert_source_link"] = "%s/app/discover" % dashboard.rstrip("/")

    return payload


def main(argv):
    if len(argv) < 4:
        debug("custom-iris: usage: custom-iris <alert_file> <api_key> <hook_url> [options]")
        return 1

    alert_file, api_key, hook_url = argv[1], argv[2], argv[3]

    # ossec.conf is rendered from values and lives in git, so the key is not put
    # there. "file:<path>" reads it from a file an init container wrote out of a
    # Secret - the same trust boundary as the rest of /var/ossec.
    if api_key.startswith("file:"):
        try:
            with open(api_key[len("file:"):]) as handle:
                api_key = handle.read().strip()
        except OSError as exc:
            debug("custom-iris: cannot read api key: %s" % exc)
            return 1
    options = {}
    for arg in argv[4:]:
        if arg.endswith("options"):
            try:
                with open(arg) as handle:
                    options = json.load(handle)
            except (OSError, ValueError) as exc:
                debug("custom-iris: ignoring unreadable options file %s: %s" % (arg, exc))
    if options.get("options_file"):
        try:
            with open(options["options_file"]) as handle:
                merged = json.load(handle)
            merged.update(options)
            options = merged
        except (OSError, ValueError) as exc:
            debug("custom-iris: ignoring unreadable options_file %s: %s"
                  % (options["options_file"], exc))

    with open(alert_file) as handle:
        alert = json.load(handle)

    level = int((alert.get("rule") or {}).get("level") or 0)
    minimum = int(options.get("min_level", 0))
    if level < minimum:
        debug("custom-iris: level %d below min_level %d, skipping" % (level, minimum))
        return 0

    timeout = int(options.get("timeout", 20))
    payload = build_alert(
        alert, options,
        resolve_customer=lambda name: lookup_customer_id(hook_url, api_key, name, timeout))
    url = "%s/alerts/add" % hook_url.rstrip("/")

    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        method="POST",
        headers={"Authorization": "Bearer %s" % api_key,
                 "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as reply:
            status, raw = reply.status, reply.read()
    except urllib.error.HTTPError as exc:
        debug("custom-iris: IRIS refused alert (HTTP %d): %s" % (exc.code, exc.read()[:500]))
        return 1
    except urllib.error.URLError as exc:
        debug("custom-iris: cannot reach IRIS at %s: %s" % (url, exc.reason))
        return 1

    # IRIS answers 200 with {"status": "error"} for validation failures, so the
    # status code alone is not enough to know the alert landed.
    body = {}
    try:
        body = json.loads(raw)
    except ValueError:
        pass
    if status >= 300 or body.get("status") == "error":
        debug("custom-iris: IRIS refused alert (HTTP %d): %s" % (status, json.dumps(body)[:500]))
        return 1

    alert_id = (body.get("data") or {}).get("alert_id")
    debug("custom-iris: created IRIS alert %s for Wazuh rule %s"
          % (alert_id, (alert.get("rule") or {}).get("id")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
