#!/usr/bin/env python3
"""IRIS closed cases -> MISP sightings.

When an IRIS case is closed with a true-positive outcome (IRIS 2.4 case
status_id 2 "true positive with impact" or 4 "true positive without impact"),
every indicator of the case that MISP knows gets a sighting (type 0), so MISP
shows that the indicator was seen in a confirmed incident. Optional:

  * CREATE_EVENTS=true: indicators MISP does not know yet go into one new,
    unpublished MISP event per case (distribution EVENT_DISTRIBUTION, default 0
    = this organisation only, tag tlp:amber), and are sighted too. TLP:RED
    indicators (IRIS ioc_tlp_id 1) never leave IRIS.
  * FALSE_POSITIVE_SIGHTINGS=true: cases closed as false positive (status_id 1)
    add false-positive sightings (type 1) for the indicators MISP knows.

The case is then tagged misp:sighted (misp:error when MISP refused), so it is
handled once; remove the tag to run it again. Only cases closed within
LOOKBACK_DAYS are considered, so enabling the job does not replay history.

Dry run unless DRY_RUN=false. Environment: IRIS_URL, IRIS_API_KEY, MISP_URL,
MISP_KEY (a MISP auth key whose user may add sightings, and events when
CREATE_EVENTS), MISP_VERIFY_TLS (default true), SIGHTING_SOURCE (default
kubesoc), LOOKBACK_DAYS (7), MAX_CASES (20 case details read per run).
Standard library only.
"""
import datetime
import sys

import kubesoc_iris as ki
from kubesoc_iris import env, truthy

TAG_DONE, TAG_ERROR = "misp:sighted", "misp:error"
TLP_RED = 1

# IRIS IOC type -> (MISP type, MISP category) for new attributes.
NETWORK = "Network activity"
PAYLOAD = "Payload delivery"
MISP_TYPES = {
    "ip-dst": ("ip-dst", NETWORK), "ip-src": ("ip-src", NETWORK), "ip-any": ("ip-dst", NETWORK),
    "ip-dst|port": ("ip-dst|port", NETWORK), "ip-src|port": ("ip-src|port", NETWORK),
    "domain": ("domain", NETWORK), "hostname": ("hostname", NETWORK), "url": ("url", NETWORK),
    "uri": ("uri", NETWORK), "user-agent": ("user-agent", NETWORK),
    "md5": ("md5", PAYLOAD), "sha1": ("sha1", PAYLOAD), "sha256": ("sha256", PAYLOAD),
    "sha512": ("sha512", PAYLOAD), "filename": ("filename", PAYLOAD),
    "filename|md5": ("filename|md5", PAYLOAD), "filename|sha1": ("filename|sha1", PAYLOAD),
    "filename|sha256": ("filename|sha256", PAYLOAD),
    "email-src": ("email-src", PAYLOAD), "email-dst": ("email-dst", NETWORK),
    "email-subject": ("email-subject", PAYLOAD),
}


class Misp:
    def __init__(self, url, key, verify_tls=True, timeout=60):
        self.url = url.rstrip("/")
        self.headers = {"Authorization": key}
        self.verify_tls = verify_tls
        self.timeout = timeout

    def call(self, method, path, body=None):
        return ki.http(method, self.url + path, self.headers, body, self.timeout, self.verify_tls)

    def known(self, values):
        """The subset of values that some MISP attribute has."""
        if not values:
            return set()
        resp = self.call("POST", "/attributes/restSearch",
                         {"returnFormat": "json", "value": sorted(values), "limit": 5000,
                          "deleted": [0], "includeEventTags": False}) or {}
        attrs = (resp.get("response") or {}).get("Attribute", []) if isinstance(resp, dict) else []
        found = set()
        for a in attrs:
            found.add(a.get("value"))
            # Composite attributes (filename|sha256) match on either half.
            for part in str(a.get("value", "")).split("|"):
                found.add(part)
        return found & set(values)

    def sight(self, values, kind, source):
        if values:
            self.call("POST", "/sightings/add", {"values": sorted(values), "type": str(kind), "source": source})

    def add_event(self, info, attributes, distribution):
        return self.call("POST", "/events/add", {"Event": {
            "info": info, "distribution": str(distribution), "threat_level_id": "2", "analysis": "2",
            "published": False, "Tag": [{"name": "tlp:amber"}], "Attribute": attributes}})


def main():
    dry_run = truthy(env("DRY_RUN", "true"))
    mode = "DRY-RUN" if dry_run else "APPLY"
    iris = ki.Iris(env("IRIS_URL"), env("IRIS_API_KEY"))
    misp = Misp(env("MISP_URL"), env("MISP_KEY"), truthy(env("MISP_VERIFY_TLS", "true")))
    source = env("SIGHTING_SOURCE", "kubesoc")
    create = truthy(env("CREATE_EVENTS", "false"))
    fp_sightings = truthy(env("FALSE_POSITIVE_SIGHTINGS", "false"))
    distribution = int(env("EVENT_DISTRIBUTION", "0"))
    since = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=int(env("LOOKBACK_DAYS", "7")))
    max_cases = int(env("MAX_CASES", "20"))

    todo, read = [], 0
    for listed in sorted(iris.cases(), key=lambda c: -int(ki.case_id(c) or 0)):
        closed = ki.case_closed_at(listed)
        has_close = any(k in listed for k in ("case_close_date", "close_date", "state_name"))
        if has_close and not (closed and closed >= since):
            continue
        if ("case_tags" in listed or "tags" in listed) and \
                {TAG_DONE, TAG_ERROR} & set(ki.case_tags(listed)):
            continue
        if read >= max_cases:
            break
        read += 1
        case = iris.full_case(listed)
        closed = ki.case_closed_at(case)
        if not (closed and closed >= since) or {TAG_DONE, TAG_ERROR} & set(ki.case_tags(case)):
            continue
        status = ki.case_status(case)
        if status in ki.TRUE_POSITIVE or (fp_sightings and status in ki.FALSE_POSITIVE):
            todo.append(case)
    print(f"{mode}: {len(todo)} closed case(s) to report to MISP (read {read})", flush=True)

    errors = 0
    for case in todo:
        cid, status = ki.case_id(case), ki.case_status(case)
        tp = status in ki.TRUE_POSITIVE
        try:
            iocs = [i for i in iris.iocs(cid) if str(i.get("ioc_value") or "").strip()]
            values = {str(i["ioc_value"]).strip() for i in iocs}
            known = misp.known(values)
            new = [] if not (tp and create) else [
                i for i in iocs if str(i["ioc_value"]).strip() not in known
                and ki.ioc_type(i) in MISP_TYPES and i.get("ioc_tlp_id") != TLP_RED]
            print(f"{mode} case {cid} ({ki.CASE_STATUS.get(status)}): {len(values)} indicator(s), "
                  f"{len(known)} known to MISP, {len(new)} for a new event", flush=True)
            if dry_run:
                continue
            if new:
                attrs = [{"type": MISP_TYPES[ki.ioc_type(i)][0], "category": MISP_TYPES[ki.ioc_type(i)][1],
                          "value": str(i["ioc_value"]).strip(), "to_ids": True,
                          "comment": f"IRIS case {cid}"} for i in new]
                misp.add_event(f"{source}: IRIS case {cid} - {str(case.get('case_name') or '')[:150]}",
                               attrs, distribution)
            misp.sight(known | {a["ioc_value"].strip() for a in new}, 0 if tp else 1, source)
            iris.set_case_tags(cid, ki.case_tags(case) + [TAG_DONE])
        except Exception as exc:
            errors += 1
            print(f"ERROR case {cid}: {exc}", flush=True)
            if not dry_run:
                try:
                    iris.set_case_tags(cid, ki.case_tags(case) + [TAG_ERROR])
                except Exception as exc2:
                    print(f"ERROR case {cid}: could not tag: {exc2}", flush=True)
    print(f"{mode} done: {errors} error(s)", flush=True)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
