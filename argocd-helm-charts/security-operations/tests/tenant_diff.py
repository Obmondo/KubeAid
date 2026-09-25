#!/usr/bin/env python3
"""Assert that render B (N+1 tenants) differs from render A (N tenants) only by
entries of the added tenant.

Usage: tenant_diff.py <render-a.json> <render-b.json> <marker> [<marker>...]

Both inputs are JSON arrays of Kubernetes objects (yq ea -o=json '[.]').
Every string that holds JSON or YAML (ConfigMap files, base64 Secret files) is
parsed, then from B every mapping key and every list item that mentions a
marker is removed. What is left must equal A exactly. Objects that exist only
in B must carry a marker in their name. Prints one line per changed object.
"""
import base64
import json
import subprocess
import sys


def parse_text(text):
    """A string holding JSON or YAML, parsed; other strings unchanged."""
    stripped = text.strip()
    if not stripped:
        return text
    try:
        return json.loads(stripped)
    except ValueError:
        pass
    if "\n" in stripped and ":" in stripped and not stripped.startswith("<"):
        res = subprocess.run(["yq", "-o=json", "-I=0", "."], input=text,
                             capture_output=True, text=True)
        if res.returncode == 0 and res.stdout.strip() not in ("", "null"):
            try:
                value = json.loads(res.stdout)
                if isinstance(value, (dict, list)):
                    return value
            except ValueError:
                pass
    return text


def expand(obj):
    if isinstance(obj, dict):
        return {k: expand(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [expand(v) for v in obj]
    if isinstance(obj, str):
        parsed = parse_text(obj)
        return expand(parsed) if parsed is not obj else obj
    return obj


def load(path):
    with open(path) as handle:
        docs = [d for d in json.load(handle) if isinstance(d, dict) and d.get("kind")]
    out = {}
    for doc in docs:
        if doc["kind"] == "Secret" and doc.get("data"):
            doc["data"] = {k: base64.b64decode(v).decode("utf-8", "replace")
                           for k, v in doc["data"].items()}
        key = "%s/%s" % (doc["kind"], doc["metadata"]["name"])
        out[key] = expand(doc)
    return out


def mentions(value, markers):
    text = json.dumps(value) if not isinstance(value, str) else value
    return any(m in text for m in markers)


def strip(obj, markers):
    if isinstance(obj, dict):
        return {k: strip(v, markers) for k, v in obj.items() if not mentions(k, markers)}
    if isinstance(obj, list):
        return [strip(v, markers) for v in obj if not mentions(v, markers)]
    return obj


def main(argv):
    a, b, markers = load(argv[1]), load(argv[2]), argv[3:]
    bad = []
    for key in sorted(set(a) - set(b)):
        bad.append("only in the smaller render: %s" % key)
    for key in sorted(set(b) - set(a)):
        if mentions(key, markers):
            print("added: %s" % key)
        else:
            bad.append("added without marker: %s" % key)
    changed = 0
    for key in sorted(set(a) & set(b)):
        if a[key] == b[key]:
            continue
        if strip(b[key], markers) == a[key]:
            changed += 1
            print("tenant entries only: %s" % key)
        else:
            bad.append("changed beyond the new tenant: %s" % key)
    for line in bad:
        print("FAIL: %s" % line)
    print("changed objects: %d" % changed)
    return 1 if bad or changed == 0 else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
