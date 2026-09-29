"""Shared plumbing for the kubesoc IRIS jobs: environment, HTTP and the IRIS API.

Standard library only, so the jobs run in the IRIS app image (python3) with
nothing installed. Used by ai_assist.py and misp_sightings.py.

IRIS v2.4 API calls used (all with an API key, Authorization: Bearer):
  GET  /alerts/filter                       New alerts (triage)
  POST /alerts/update/<id>                  alert note and tags
  GET  /manage/cases/list                   every case the key can see
  GET  /manage/cases/<id>                   one case: tags, state, outcome
  POST /manage/cases/update/<id>            case tags only
  GET  /case/ioc/list?cid=                  case indicators
  GET  /case/assets/list?cid=               case assets
  GET  /case/timeline/events/list?cid=      case timeline
  GET  /case/notes/directories/filter?cid=  note directories with note titles
  GET  /case/notes/<id>?cid=                one note
  POST /case/notes/directories/add?cid=     note directory
  POST /case/notes/add?cid=                 note
"""
import datetime
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request

# IRIS 2.4 case outcome (cases.status_id, "Outcome" in the case summary).
CASE_STATUS = {
    0: "unknown",
    1: "false_positive",
    2: "true_positive_with_impact",
    3: "not_applicable",
    4: "true_positive_without_impact",
    5: "legitimate",
}
TRUE_POSITIVE = (2, 4)
FALSE_POSITIVE = (1,)


def env(name, default=None, required=True):
    value = os.environ.get(name, default)
    if required and (value is None or value == ""):
        sys.exit(f"missing environment variable {name}")
    return value


def truthy(value):
    return str(value).strip().lower() in ("1", "true", "yes", "on", "y")


def http(method, url, headers=None, body=None, timeout=30, verify_tls=True):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Content-Type": "application/json", "Accept": "application/json", **(headers or {})})
    ctx = None
    if url.startswith("https://") and not verify_tls:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            raw = resp.read()
    except urllib.error.HTTPError as err:
        # Never echo the query string: it may carry a key.
        raise RuntimeError(f"{method} {url.split('?')[0]} -> HTTP {err.code}: "
                           f"{err.read()[:200].decode(errors='replace')}") from None
    return json.loads(raw) if raw else None


def split_tags(value):
    """IRIS returns tags as "a,b", a list of strings or a list of {tag_title}."""
    if not value:
        return []
    if isinstance(value, str):
        items = value.split(",")
    else:
        items = [v.get("tag_title") or v.get("title") or "" if isinstance(v, dict) else str(v)
                 for v in value]
    return [t.strip() for t in items if t and t.strip()]


def parse_time(value):
    """IRIS dates: "2026-09-28", "2026-09-28T10:00:00[.ffffff][Z]" or "09/28/2026"."""
    if not value:
        return None
    s = str(value).strip().replace("Z", "+00:00")
    for fmt in (None, "%Y-%m-%d", "%m/%d/%Y", "%Y-%m-%d %H:%M:%S"):
        try:
            d = datetime.datetime.fromisoformat(s) if fmt is None else datetime.datetime.strptime(s, fmt)
        except ValueError:
            continue
        return d if d.tzinfo else d.replace(tzinfo=datetime.timezone.utc)
    return None


class Iris:
    def __init__(self, url, api_key, timeout=30):
        self.url = url.rstrip("/")
        self.headers = {"Authorization": "Bearer " + api_key}
        self.timeout = timeout

    def call(self, method, path, body=None, **params):
        q = f"?{urllib.parse.urlencode(params)}" if params else ""
        resp = http(method, f"{self.url}{path}{q}", self.headers, body, self.timeout)
        if isinstance(resp, dict) and resp.get("status") == "error":
            raise RuntimeError(f"{method} {path}: {str(resp.get('message'))[:200]}")
        return (resp or {}).get("data") if isinstance(resp, dict) else resp

    # --- alerts --------------------------------------------------------------
    def new_alerts(self, per_page=100):
        data = self.call("GET", "/alerts/filter", alert_status_id=2, per_page=per_page, sort="desc")
        return (data or {}).get("alerts", [])

    def update_alert(self, alert, note, tags):
        # IRIS makes the updating user the owner of an unowned alert; -1 keeps it unowned.
        owner = alert.get("alert_owner_id")
        self.call("POST", f"/alerts/update/{alert['alert_id']}", {
            "alert_note": note, "alert_tags": ",".join(dict.fromkeys(tags)),
            "alert_owner_id": owner if owner else -1})

    # --- cases ---------------------------------------------------------------
    def cases(self):
        data = self.call("GET", "/manage/cases/list")
        if isinstance(data, dict):
            data = data.get("cases") or data.get("data") or []
        return data or []

    def case(self, cid):
        return self.call("GET", f"/manage/cases/{cid}") or {}

    def full_case(self, listed):
        """The list entry merged with the case details (tags and outcome live there)."""
        cid = case_id(listed)
        detail = self.case(cid)
        return {**listed, **(detail if isinstance(detail, dict) else {}), "case_id": cid}

    def set_case_tags(self, cid, tags):
        self.call("POST", f"/manage/cases/update/{cid}", {"case_tags": ",".join(dict.fromkeys(tags))})

    def iocs(self, cid):
        data = self.call("GET", "/case/ioc/list", cid=cid) or {}
        return data.get("ioc", []) if isinstance(data, dict) else data

    def assets(self, cid):
        data = self.call("GET", "/case/assets/list", cid=cid) or {}
        return data.get("assets", []) if isinstance(data, dict) else data

    def timeline(self, cid):
        data = self.call("GET", "/case/timeline/events/list", cid=cid) or {}
        return data.get("timeline", []) if isinstance(data, dict) else data

    # --- notes ---------------------------------------------------------------
    def note_directories(self, cid):
        return self.call("GET", "/case/notes/directories/filter", cid=cid) or []

    def note_titles(self, cid):
        """[(note id, title, directory name)] over every directory, nested ones included."""
        out = []

        def walk(dirs):
            for d in dirs or []:
                for n in d.get("notes") or []:
                    out.append((n.get("id") or n.get("note_id"), n.get("title") or n.get("note_title") or "",
                                d.get("name") or ""))
                walk(d.get("subdirectories"))
        walk(self.note_directories(cid))
        return out

    def note(self, cid, nid):
        return self.call("GET", f"/case/notes/{nid}", cid=cid) or {}

    def directory_id(self, cid, name):
        for d in self.note_directories(cid):
            if d.get("name") == name:
                return d.get("id")
        created = self.call("POST", "/case/notes/directories/add", {"name": name}, cid=cid) or {}
        return created.get("id")

    def add_note(self, cid, directory, title, content):
        return self.call("POST", "/case/notes/add", {
            "note_title": title, "note_content": content,
            "directory_id": self.directory_id(cid, directory), "custom_attributes": {}}, cid=cid)


def case_id(case):
    return case.get("case_id") or case.get("id")


def case_tags(case):
    return split_tags(case.get("case_tags") if case.get("case_tags") is not None else case.get("tags"))


def case_closed_at(case):
    """Close time, or None while the case is open."""
    for k in ("case_close_date", "close_date"):
        t = parse_time(case.get(k))
        if t:
            return t
    state = case.get("state_name")
    if not state and isinstance(case.get("state"), dict):
        state = case["state"].get("state_name")
    if str(state or "").lower() == "closed":
        # Closed, but when is unknown: older than any look-back window.
        return datetime.datetime.min.replace(tzinfo=datetime.timezone.utc)
    return None


def case_status(case):
    try:
        return int(case.get("status_id"))
    except (TypeError, ValueError):
        return 0


def customer_name(case):
    return case.get("client_name") or case.get("customer_name") or \
        ((case.get("client") or {}).get("customer_name") if isinstance(case.get("client"), dict) else None)


def ioc_type(ioc):
    t = ioc.get("ioc_type")
    return t.get("type_name") if isinstance(t, dict) else t
