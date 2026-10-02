#!/usr/bin/env python3
"""MISP -> Wazuh CDB list export.

Pulls actionable attributes (to_ids=1, not deleted, not on a warninglist) from
MISP's restSearch, writes them as CDB lists through the Wazuh manager API and
asks analysisd on every cluster node to reload, so the change takes effect
without a restart.

Stdlib only: the image is a stock python:3-alpine, nothing is installed.
"""
import json
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.request

MISP_URL = os.environ["MISP_URL"].rstrip("/")
MISP_KEY = os.environ["MISP_KEY"]
WAZUH_URL = os.environ["WAZUH_URL"].rstrip("/")
WAZUH_USER = os.environ["WAZUH_USER"]
WAZUH_PASS = os.environ["WAZUH_PASS"]
WAZUH_VERIFY = os.environ.get("WAZUH_VERIFY_TLS", "true").lower() == "true"
# JSON: [{"name": "misp-malicious-ip", "types": ["ip-dst", "ip-src"]}, ...]
LISTS = json.loads(os.environ["LISTS"])
PAGE = int(os.environ.get("MISP_PAGE_SIZE", "5000"))
MAX_PER_LIST = int(os.environ.get("MAX_PER_LIST", "200000"))
PUBLISHED_ONLY = os.environ.get("MISP_PUBLISHED_ONLY", "false").lower() == "true"
DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"

wazuh_ctx = ssl.create_default_context()
if not WAZUH_VERIFY:
    wazuh_ctx.check_hostname = False
    wazuh_ctx.verify_mode = ssl.CERT_NONE


# Wazuh validates CDB content with this regex (wazuh/core/cdb_list.py,
# validate_cdb_list) and rejects the WHOLE file on the first line that fails, so
# one malformed indicator silently costs the entire list. Keys and values that
# contain ":" must be quoted - an IPv6 address is the case that bites.
CDB_LINE = re.compile(r'(?:^"([\w\-: ]+?)"|^[^:"\s]+):(?:"([\w\-: ]*?)"$|[^:\"]*$)')


def cdb_line(key, value):
    """A line Wazuh will accept, or None if the key cannot be represented."""
    if ":" in key or " " in key:
        key = '"%s"' % key
    if ":" in value:
        value = '"%s"' % value
    line = "%s:%s" % (key, value)
    return line if CDB_LINE.match(line) else None


def log(msg):
    print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), msg, flush=True)


def http(url, method="GET", body=None, headers=None, ctx=None, expect=(200,)):
    req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=120) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        payload = e.read()[:400]
        raise SystemExit(f"{method} {url} -> HTTP {e.code}: {payload!r}")


# ---- MISP -------------------------------------------------------------------
def misp_attributes(types):
    """Every actionable attribute of the given types, paged."""
    seen, page = {}, 1
    while True:
        q = {
            "returnFormat": "json",
            "type": types,
            "to_ids": 1,
            "deleted": 0,
            "enforceWarninglist": 1,
            "limit": PAGE,
            "page": page,
        }
        if PUBLISHED_ONLY:
            q["published"] = 1
        _, raw = http(
            f"{MISP_URL}/attributes/restSearch", "POST", json.dumps(q).encode(),
            {"Authorization": MISP_KEY, "Accept": "application/json",
             "Content-Type": "application/json"},
        )
        attrs = json.loads(raw).get("response", {}).get("Attribute", [])
        for a in attrs:
            v = a["value"].strip().lower()
            # ip-dst|port style composite values: keep the address only
            if "|" in v:
                v = v.split("|", 1)[0]
            if v and v not in seen:
                seen[v] = a.get("event_id", "?")
            if len(seen) >= MAX_PER_LIST:
                log(f"  cap MAX_PER_LIST={MAX_PER_LIST} reached")
                return seen
        if len(attrs) < PAGE:
            return seen
        page += 1


# ---- Wazuh ------------------------------------------------------------------
def wazuh_token():
    auth = ("%s:%s" % (WAZUH_USER, WAZUH_PASS)).encode()
    import base64
    _, raw = http(
        f"{WAZUH_URL}/security/user/authenticate?raw=true", "POST",
        headers={"Authorization": "Basic " + base64.b64encode(auth).decode()},
        ctx=wazuh_ctx,
    )
    return raw.decode().strip()


def wazuh_put_list(token, name, content):
    # The API answers 200 even when it refuses the file - the failure is in the
    # body, as error != 0 with the detail in failed_items. Checking only the
    # status code loses a whole list without a word.
    _, raw = http(
        f"{WAZUH_URL}/lists/files/{name}?overwrite=true", "PUT", content.encode(),
        {"Authorization": f"Bearer {token}", "Content-Type": "application/octet-stream"},
        ctx=wazuh_ctx,
    )
    d = json.loads(raw)
    if d.get("error") or d.get("data", {}).get("total_failed_items"):
        raise SystemExit(f"upload of {name} refused: {json.dumps(d.get('data', d))[:400]}")


def wazuh_reload(token):
    _, raw = http(
        f"{WAZUH_URL}/cluster/analysisd/reload", "PUT",
        headers={"Authorization": f"Bearer {token}"}, ctx=wazuh_ctx,
    )
    d = json.loads(raw).get("data", {})
    return d.get("total_affected_items", 0), d.get("total_failed_items", 0), d.get("failed_items", [])


# ---- main -------------------------------------------------------------------
def main():
    log(f"MISP {MISP_URL} -> Wazuh {WAZUH_URL}, {len(LISTS)} lists, dry_run={DRY_RUN}")
    rendered = {}
    for spec in LISTS:
        entries = misp_attributes(spec["types"])
        # CDB format is key:value per line; the value is free text and shows up
        # in the alert, so point it back at the MISP event.
        lines, dropped = [], 0
        for v, ev in sorted(entries.items()):
            line = cdb_line(v, f"MISP event {ev}")
            if line is None:
                dropped += 1
                continue
            lines.append(line)
        rendered[spec["name"]] = "\n".join(lines) + ("\n" if lines else "")
        log(f"  {spec['name']}: {len(lines)} entries from types {spec['types']}"
            + (f" ({dropped} unrepresentable, dropped)" if dropped else ""))

    if DRY_RUN:
        log("dry run, not touching Wazuh")
        return

    token = wazuh_token()
    for name, content in rendered.items():
        wazuh_put_list(token, name, content)
        log(f"  uploaded {name} ({len(content)} bytes)")
    ok, failed, items = wazuh_reload(token)
    log(f"analysisd reload: {ok} nodes ok, {failed} failed {items if failed else ''}")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
