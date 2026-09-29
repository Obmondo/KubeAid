#!/usr/bin/env python3
"""Check the NetworkPolicies of a rendered chart.

Usage: netpol_check.py <render.json> --ns NS [--ns NS ...]
                       [--open-ingress PORTS] [--open-egress PORTS]
                       [--world-ingress PORTS] [--world-egress PORTS]

<render.json> is a JSON array of objects (yq ea -o=json '[.]'). For every
namespace given with --ns:

  * a default deny exists: a NetworkPolicy with an empty podSelector and both
    policyTypes;
  * every workload's pods (Deployment, StatefulSet, DaemonSet, Job, CronJob,
    and the pods of CNPG Cluster, RabbitmqCluster and MariaDB objects) are
    selected by at least one other NetworkPolicy or CiliumNetworkPolicy;
  * no rule is open to everything: an ingress rule without `from` (or with an
    empty one) or an ipBlock 0.0.0.0/0 or ::/0 is allowed only on
    --open-ingress ports (comma separated, default none), and on egress only on
    --open-egress ports; a Cilium world/all entity or 0.0.0.0/0 CIDR only on
    --world-ingress / --world-egress ports. An egress rule without `to` is
    allowed for DNS (53) only.

Exits non-zero and prints one line per problem.
"""
import argparse
import json
import sys

OPEN_CIDRS = {"0.0.0.0/0", "::/0"}
WORLD_ENTITIES = {"world", "all"}


def pod_labels(obj):
    """(description, labels) for the pods an object runs, or None."""
    kind = obj.get("kind")
    meta = obj.get("metadata", {})
    name = meta.get("name", "")
    spec = obj.get("spec", {}) or {}
    labels = None
    if kind in ("Deployment", "StatefulSet", "DaemonSet"):
        labels = dict(spec.get("template", {}).get("metadata", {}).get("labels", {}) or {})
    elif kind == "Job":
        labels = dict(spec.get("template", {}).get("metadata", {}).get("labels", {}) or {})
        labels.setdefault("job-name", name)
    elif kind == "CronJob":
        tmpl = spec.get("jobTemplate", {}).get("spec", {}).get("template", {})
        labels = dict(tmpl.get("metadata", {}).get("labels", {}) or {})
    elif kind == "Cluster" and obj.get("apiVersion", "").split("/")[0] == "postgresql.cnpg.io":
        labels = {"cnpg.io/cluster": name}
    elif kind == "RabbitmqCluster":
        labels = {"app.kubernetes.io/name": name}
    elif kind == "MariaDB":
        labels = {"app.kubernetes.io/name": "mariadb", "app.kubernetes.io/instance": name}
    if labels is None:
        return None
    return f"{kind}/{name}", labels


def selects(selector, labels):
    """Whether a LabelSelector (matchLabels, matchExpressions) matches labels."""
    if selector is None:
        return False
    for k, v in (selector.get("matchLabels") or {}).items():
        if labels.get(k) != v:
            return False
    for e in selector.get("matchExpressions") or []:
        key, op, vals = e.get("key"), e.get("operator"), e.get("values") or []
        if op == "Exists" and key not in labels:
            return False
        if op == "DoesNotExist" and key in labels:
            return False
        if op == "In" and labels.get(key) not in vals:
            return False
        if op == "NotIn" and labels.get(key) in vals:
            return False
    return True


def is_default_deny(np):
    spec = np.get("spec", {})
    return (
        np.get("kind") == "NetworkPolicy"
        and not (spec.get("podSelector") or {}).get("matchLabels")
        and not (spec.get("podSelector") or {}).get("matchExpressions")
        and set(spec.get("policyTypes") or []) == {"Ingress", "Egress"}
    )


def ports_of(rule, cilium=False):
    if cilium:
        out = set()
        for tp in rule.get("toPorts") or []:
            for p in tp.get("ports") or []:
                out.add(int(p.get("port")))
        return out
    return {int(p["port"]) for p in rule.get("ports") or [] if "port" in p}


def check_rule(where, direction, rule, peers_key, allowed, problems, cilium=False):
    ports = ports_of(rule, cilium)
    if cilium:
        ent_key = "fromEntities" if direction == "ingress" else "toEntities"
        cidr_key = "fromCIDR" if direction == "ingress" else "toCIDR"
        wide = bool(set(rule.get(ent_key) or []) & WORLD_ENTITIES) or bool(
            set(rule.get(cidr_key) or []) & OPEN_CIDRS
        ) or any(c.get("cidr") in OPEN_CIDRS for c in rule.get(cidr_key + "Set") or [])
    else:
        peers = rule.get(peers_key)
        if not peers:
            if direction == "egress" and ports and ports <= {53}:
                return
            problems.append(f"{where}: {direction} rule open to every peer on ports {sorted(ports) or 'all'}")
            return
        wide = any((p.get("ipBlock") or {}).get("cidr") in OPEN_CIDRS for p in peers)
    if not wide:
        return
    if not ports or not ports <= allowed:
        problems.append(
            f"{where}: {direction} to/from anywhere on ports {sorted(ports) or 'all'} "
            f"(allowed: {sorted(allowed) or 'none'})"
        )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("render")
    ap.add_argument("--ns", action="append", required=True)
    ap.add_argument("--open-ingress", default="")
    ap.add_argument("--open-egress", default="")
    ap.add_argument("--world-ingress", default="")
    ap.add_argument("--world-egress", default="")
    args = ap.parse_args()

    def portset(v):
        return {int(p) for p in v.split(",") if p}

    open_in, open_eg = portset(args.open_ingress), portset(args.open_egress)
    world_in, world_eg = portset(args.world_ingress), portset(args.world_egress)
    with open(args.render) as f:
        objs = [o for o in json.load(f) if isinstance(o, dict) and o.get("kind")]

    problems = []
    for ns in args.ns:
        in_ns = [o for o in objs if o.get("metadata", {}).get("namespace", ns) == ns]
        nps = [o for o in in_ns if o["kind"] == "NetworkPolicy"]
        cnps = [o for o in in_ns if o["kind"] == "CiliumNetworkPolicy"]
        if not any(is_default_deny(n) for n in nps):
            problems.append(f"{ns}: no default-deny NetworkPolicy")
        for o in in_ns:
            pl = pod_labels(o)
            if pl is None:
                continue
            desc, labels = pl
            covered = any(not is_default_deny(n) and selects(n["spec"].get("podSelector"), labels) for n in nps) or any(
                selects(c["spec"].get("endpointSelector"), labels) for c in cnps
            )
            if not covered:
                problems.append(f"{ns}: {desc} (labels {labels}) has no NetworkPolicy of its own")
        for n in nps:
            where = f"{ns}: NetworkPolicy/{n['metadata']['name']}"
            for r in n["spec"].get("ingress") or []:
                check_rule(where, "ingress", r, "from", open_in, problems)
            for r in n["spec"].get("egress") or []:
                check_rule(where, "egress", r, "to", open_eg, problems)
        for c in cnps:
            where = f"{ns}: CiliumNetworkPolicy/{c['metadata']['name']}"
            for r in c["spec"].get("ingress") or []:
                check_rule(where, "ingress", r, None, world_in, problems, cilium=True)
            for r in c["spec"].get("egress") or []:
                check_rule(where, "egress", r, None, world_eg, problems, cilium=True)

    for p in problems:
        print(p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
