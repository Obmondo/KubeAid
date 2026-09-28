#!/usr/bin/env python3
"""kubesoc AI assistant for DFIR-IRIS, with a self-hosted model (Ollama).

    python3 ai_assist.py triage summary hunt     # modes run in this order

  triage   New alerts without an ai: tag get a note (severity, false-positive
           guess, category, summary, next step, ATT&CK techniques) and tags
           ai:triaged, ai:sev:<level>, ai:fp:<...>, ai:attack:<id> (ai:error when
           the model fails, so an alert is not retried forever).
  summary  Cases tagged ai:summarize (and, with SUMMARY_ON_CLOSE, cases closed in
           the last SUMMARY_LOOKBACK_DAYS days) get an incident summary and report
           draft as a note in the "AI drafts" directory; the tag becomes
           ai:summarized (ai:summarize:error on failure). Remove ai:summarized and
           add ai:summarize again for a new draft.
  hunt     A note titled "ai:hunt: <question>" (or "ai:hunt" with the question as
           its content) in an open case gets an answer note with a suggested
           Wazuh DQL filter, an OpenSearch query and a Velociraptor VQL hunt.

The assistant only writes notes and tags. It never changes severity, status or
outcome, never runs a query, hunt or response, and treats everything it reads
as untrusted data (kubesoc_ai.py). Every note says "AI draft - review
required" and names the model and prompt version.

Dry run unless DRY_RUN=false. Environment:

  IRIS_URL, IRIS_API_KEY, OLLAMA_URL, MODEL
  DRY_RUN                 true|false (default true)
  TIMEOUT_SECONDS         per model call (default 180)
  DEADLINE_SECONDS        start no model call after this many seconds (default 600)
  REDACT                  mask secret-like strings before the model sees them (default true)
  PROMPTS_DIR             prompt/schema overrides, <mode>.system.txt / .schema.json (default /prompts)
  NOTE_DIRECTORY          IRIS note directory for AI notes (default "AI drafts")
  MAX_PER_RUN, MIN_LEVEL  triage: alerts per run (default 5), minimum Wazuh rule level (0)
  SUMMARY_MAX_PER_RUN     default 1
  SUMMARY_ON_CLOSE        also draft for newly closed cases (default false)
  SUMMARY_LOOKBACK_DAYS   default 3
  SUMMARY_MAX_CASES       cases whose details are read per run when the list lacks tags (default 50)
  HUNT_MAX_PER_RUN        default 2
  HUNT_MAX_CASES          open cases scanned for questions per run (default 50)
"""
import datetime
import json
import sys
import time

import kubesoc_ai as ai
import kubesoc_iris as ki
from kubesoc_iris import env, truthy

TAG_SUMMARIZE, TAG_SUMMARIZED, TAG_SUMMARY_ERROR = "ai:summarize", "ai:summarized", "ai:summarize:error"
HUNT_PREFIX = "ai:hunt"


class Run:
    def __init__(self):
        self.dry_run = truthy(env("DRY_RUN", "true"))
        self.mode = "DRY-RUN" if self.dry_run else "APPLY"
        self.iris = ki.Iris(env("IRIS_URL"), env("IRIS_API_KEY"))
        self.ollama, self.model = env("OLLAMA_URL"), env("MODEL")
        self.timeout = int(env("TIMEOUT_SECONDS", "180"))
        self.deadline = time.monotonic() + int(env("DEADLINE_SECONDS", "600"))
        self.redact = truthy(env("REDACT", "true"))
        self.directory = env("NOTE_DIRECTORY", "AI drafts")
        self.errors = 0

    def time_left(self):
        return time.monotonic() + self.timeout < self.deadline

    def ask(self, prompt, data, num_predict, input_limit):
        return ai.ask(self.ollama, self.model, prompt, data, self.timeout, num_predict, input_limit,
                      self.redact)

    def log(self, text):
        print(f"{self.mode} {text}", flush=True)


# --- triage ---------------------------------------------------------------

def rule_level(alert):
    content = alert.get("alert_source_content") or {}
    level = (content.get("rule") or {}).get("level") if isinstance(content, dict) else None
    if level is None:
        for tag in ki.split_tags(alert.get("alert_tags")):
            if tag.startswith("level:"):
                level = tag.split(":", 1)[1]
    try:
        return int(level)
    except (TypeError, ValueError):
        return None


def alert_view(alert):
    """What the model sees of an alert: the fields an analyst would look at."""
    content = alert.get("alert_source_content") or {}
    if not isinstance(content, dict):
        content = {"raw": str(content)[:1500]}
    keep = {k: content[k] for k in ("rule", "agent", "location", "decoder", "syscheck", "data") if k in content}
    if "full_log" in content:
        keep["full_log"] = str(content["full_log"])[:1500]
    return {
        "title": alert.get("alert_title"),
        "description": (alert.get("alert_description") or "")[:1500],
        "tags": alert.get("alert_tags"),
        "iocs": [{"type": ki.ioc_type(i), "value": i.get("ioc_value")} for i in (alert.get("iocs") or [])][:20],
        "assets": [a.get("asset_name") for a in (alert.get("assets") or [])][:10],
        "wazuh_alert": keep,
    }


def triage(run):
    prompt = ai.load_prompt("triage")
    max_per_run = int(env("MAX_PER_RUN", "5"))
    min_level = int(env("MIN_LEVEL", "0"))
    alerts = run.iris.new_alerts()
    todo = []
    for a in alerts:
        tags = ki.split_tags(a.get("alert_tags"))
        if any(t in ("ai:triaged", "ai:error") for t in tags):
            continue
        level = rule_level(a)
        if level is not None and level < min_level:
            continue
        todo.append(a)
    run.log(f"triage: {len(alerts)} New alerts, {len(todo)} to triage, up to {max_per_run} "
            f"with {run.model} ({prompt.label})")
    for a in todo[:max_per_run]:
        if not run.time_left():
            run.log("triage: out of time")
            break
        aid = a["alert_id"]
        tags = ki.split_tags(a.get("alert_tags"))
        try:
            answer, seconds, tokens = run.ask(prompt, alert_view(a), 500, 6000)
        except Exception as exc:
            run.errors += 1
            run.log(f"alert {aid}: model failed: {exc}")
            if not run.dry_run:
                note = (a.get("alert_note") or "") + \
                    f"\n\n---\nAI triage failed ({run.model}, prompt {prompt.label}): {ai.prose(exc, 200)}"
                run.iris.update_alert(a, note, tags + ["ai:error"])
            continue
        run.log(f"alert {aid} ({tokens} tokens, {seconds:.1f} s): {json.dumps(answer)}")
        if run.dry_run:
            continue
        techniques = ", ".join(f"{t['id']} {ai.prose(t['name'], 80)}" for t in answer["attack_techniques"])
        note = ((a.get("alert_note") or "") +
                f"\n\n---\nAI triage - advisory only. {ai.stamp(run.model, prompt)}\n"
                f"Severity: {answer['severity']}; false positive: {answer['false_positive']} "
                f"(confidence {answer['confidence']:.2f}); category: {ai.prose(answer['category'], 80)}\n"
                f"Summary: {ai.prose(answer['summary'])}\n"
                f"Suggested next action: {ai.prose(answer['next_action'])}\n"
                f"ATT&CK: {techniques or 'none suggested'}")
        new_tags = tags + ["ai:triaged", f"ai:sev:{answer['severity']}", f"ai:fp:{answer['false_positive']}"] + \
            [f"ai:attack:{t['id']}" for t in answer["attack_techniques"][:3]]
        try:
            run.iris.update_alert(a, note, new_tags)
        except Exception as exc:
            run.errors += 1
            run.log(f"ERROR alert {aid}: could not write back: {exc}")


# --- case summary ---------------------------------------------------------

def case_view(run, case):
    cid = ki.case_id(case)
    notes = []
    for nid, title, directory in run.iris.note_titles(cid):
        if directory == run.directory or title.lower().startswith(HUNT_PREFIX):
            continue  # not our own drafts, not hunting questions
        n = run.iris.note(cid, nid)
        notes.append({"title": title, "content": str(n.get("note_content") or "")[:1500]})
        if len(notes) >= 10:
            break
    status = ki.case_status(case)
    return {
        "name": case.get("case_name") or case.get("name"),
        "tenant": ki.customer_name(case),
        "description": str(case.get("case_description") or case.get("description") or "")[:3000],
        "opened": case.get("case_open_date") or case.get("open_date"),
        "closed": case.get("case_close_date") or case.get("close_date"),
        "outcome": ki.CASE_STATUS.get(status, "unknown"),
        "tags": ki.case_tags(case),
        "assets": [{"name": a.get("asset_name"), "type": a.get("asset_type"), "ip": a.get("asset_ip"),
                    "compromised": a.get("asset_compromise_status_id")} for a in run.iris.assets(cid)][:30],
        "iocs": [{"type": ki.ioc_type(i), "value": i.get("ioc_value"), "description": (i.get("ioc_description") or "")[:200]}
                 for i in run.iris.iocs(cid)][:50],
        "timeline": [{"time": e.get("event_date"), "title": e.get("event_title"),
                      "content": str(e.get("event_content") or "")[:300]} for e in run.iris.timeline(cid)][:40],
        "notes": notes,
    }


def summary_note(run, prompt, view, answer):
    lines = [ai.stamp(run.model, prompt), "",
             f"# Incident summary - {ai.prose(view['name'], 200)}", "",
             f"Tenant: {ai.prose(view['tenant'], 100)}. Outcome in IRIS: {view['outcome']}. "
             f"Model confidence {answer['confidence']:.2f}.", "",
             "## Executive summary", ai.prose(answer["summary"]), "",
             "## Impact", ai.prose(answer["impact"]), "",
             "## Timeline (from the case, as understood by the model)"]
    lines += [f"- {ai.prose(e['time'], 40)}: {ai.prose(e['event'], 300)}" for e in answer["timeline"]] or ["- none"]
    lines += ["", "## Affected assets (from the case record)"]
    lines += [f"- `{ai.prose(a['name'], 100)}` ({ai.prose(a['type'], 40)})" for a in view["assets"]] or ["- none recorded"]
    lines += ["", "## Indicators (from the case record)"]
    lines += [f"- {ai.prose(i['type'], 40)}: `{ai.prose(i['value'], 300)}`" for i in view["iocs"]] or ["- none recorded"]
    lines += ["", "## MITRE ATT&CK (suggested)"] + ai.attack_lines(answer["attack_techniques"])
    lines += ["", "## Recommended actions"] + [f"{n}. {ai.prose(a, 300)}" for n, a in
                                               enumerate(answer["recommended_actions"], 1)]
    lines += ["", "## Open questions"] + ([f"- {ai.prose(q, 300)}" for q in answer["open_questions"]] or ["- none"])
    return "\n".join(lines)


def summary(run):
    prompt = ai.load_prompt("summary")
    max_per_run = int(env("SUMMARY_MAX_PER_RUN", "1"))
    on_close = truthy(env("SUMMARY_ON_CLOSE", "false"))
    since = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(
        days=int(env("SUMMARY_LOOKBACK_DAYS", "3")))
    max_cases = int(env("SUMMARY_MAX_CASES", "50"))
    todo, fetched = [], 0

    def wanted(c):
        tags, closed = ki.case_tags(c), ki.case_closed_at(c)
        if TAG_SUMMARIZED in tags or TAG_SUMMARY_ERROR in tags:
            return False
        return TAG_SUMMARIZE in tags or bool(on_close and closed and closed >= since)

    for listed in sorted(run.iris.cases(), key=lambda c: -int(ki.case_id(c) or 0)):
        if len(todo) >= max_per_run:
            break
        # The case list may lack tags; then the newest max_cases cases are fetched.
        if "case_tags" in listed or "tags" in listed:
            if not wanted(listed):
                continue
        elif fetched >= max_cases:
            break
        fetched += 1
        case = run.iris.full_case(listed)
        if wanted(case):
            todo.append(case)
    run.log(f"summary: {len(todo)} case(s) to draft with {run.model} ({prompt.label})")
    for case in todo:
        if not run.time_left():
            run.log("summary: out of time")
            break
        cid, tags = ki.case_id(case), ki.case_tags(case)
        rest = [t for t in tags if t != TAG_SUMMARIZE]
        try:
            view = case_view(run, case)
            answer, seconds, tokens = run.ask(prompt, view, 1500, 16000)
        except Exception as exc:
            run.errors += 1
            run.log(f"case {cid}: summary failed: {exc}")
            if not run.dry_run:
                run.iris.add_note(cid, run.directory, "AI draft - case summary failed",
                                  f"{ai.stamp(run.model, prompt)}\n\nThe model call failed: {ai.prose(exc, 300)}\n"
                                  f"Remove the tag {TAG_SUMMARY_ERROR} and add {TAG_SUMMARIZE} to retry.")
                run.iris.set_case_tags(cid, rest + [TAG_SUMMARY_ERROR])
            continue
        run.log(f"case {cid} ({tokens} tokens, {seconds:.1f} s): {json.dumps(answer)[:2000]}")
        if run.dry_run:
            continue
        try:
            run.iris.add_note(cid, run.directory, "AI draft - incident summary and report (review required)",
                              summary_note(run, prompt, view, answer))
            run.iris.set_case_tags(cid, rest + [TAG_SUMMARIZED])
        except Exception as exc:
            run.errors += 1
            run.log(f"ERROR case {cid}: could not write back: {exc}")


# --- hunting --------------------------------------------------------------

def answer_title(nid):
    return f"AI hunt suggestion (re note {nid}) - review required"


def hunt_note(run, prompt, question, answer):
    lines = [ai.stamp(run.model, prompt),
             "These are suggestions only. Nothing has been run. Review and adapt each query, "
             "then run it yourself in the Wazuh dashboard or as a Velociraptor hunt.", "",
             f"**Question:** {ai.prose(question, 1000)}", "",
             f"**Understood as:** {ai.prose(answer['interpretation'])}", "",
             f"**Time range:** {ai.prose(answer['time_range'], 60)}", "",
             "## Wazuh dashboard (DQL, Discover on *:wazuh-alerts-*)", ai.code(answer["wazuh_dql"] or "(none)"), ""]
    query = answer["opensearch_query"]
    try:
        query = json.dumps(json.loads(query), indent=2)
        valid = True
    except (TypeError, ValueError):
        valid = not query.strip()
    lines += ["## OpenSearch query DSL", ai.code(query or "(none)", "json")]
    if not valid:
        lines += ["Warning: this is not valid JSON."]
    lines += ["", "## Velociraptor hunt (VQL)", ai.code(answer["velociraptor_vql"] or "(none)", "sql")]
    warn = ai.vql_warnings(answer["velociraptor_vql"])
    if warn:
        lines += [f"**Warning: the VQL calls {', '.join(warn)}, which change endpoints or reach out. "
                  f"Do not run it as is.**"]
    lines += ["", "## Caveats", ai.prose(answer["caveats"]), "",
              "## MITRE ATT&CK"] + ai.attack_lines(answer["attack_techniques"])
    return "\n".join(lines)


def hunt(run):
    prompt = ai.load_prompt("hunt")
    max_per_run = int(env("HUNT_MAX_PER_RUN", "2"))
    max_cases = int(env("HUNT_MAX_CASES", "50"))
    open_cases = [c for c in run.iris.cases() if not ki.case_closed_at(c)]
    open_cases.sort(key=lambda c: -int(ki.case_id(c) or 0))
    todo = []
    for case in open_cases[:max_cases]:
        cid = ki.case_id(case)
        notes = run.iris.note_titles(cid)
        answered = {t for _, t, _ in notes}
        for nid, title, directory in notes:
            if directory == run.directory or not title.lower().startswith(HUNT_PREFIX):
                continue
            if answer_title(nid) in answered:
                continue
            todo.append((case, nid, title))
        if len(todo) >= max_per_run:
            break
    run.log(f"hunt: {len(todo)} question(s) with {run.model} ({prompt.label})")
    for case, nid, title in todo[:max_per_run]:
        if not run.time_left():
            run.log("hunt: out of time")
            break
        cid = ki.case_id(case)
        question = title[len(HUNT_PREFIX):].lstrip(" :").strip()
        try:
            if not question:
                question = str(run.iris.note(cid, nid).get("note_content") or "").strip()
            if not question:
                raise ValueError("the note has no question (put it in the title after 'ai:hunt:' or in the content)")
            question = question[:2000]
            data = {"question": question, "case": case.get("case_name") or case.get("name"),
                    "tenant": ki.customer_name(case),
                    "case_iocs": [{"type": ki.ioc_type(i), "value": i.get("ioc_value")}
                                  for i in run.iris.iocs(cid)][:30]}
            answer, seconds, tokens = run.ask(prompt, data, 1200, 8000)
        except Exception as exc:
            run.errors += 1
            run.log(f"case {cid} note {nid}: hunt failed: {exc}")
            if not run.dry_run:
                run.iris.add_note(cid, run.directory, answer_title(nid),
                                  f"{ai.stamp(run.model, prompt)}\n\nNo suggestion: {ai.prose(exc, 300)}\n"
                                  f"Delete this note to ask again.")
            continue
        run.log(f"case {cid} note {nid} ({tokens} tokens, {seconds:.1f} s): {json.dumps(answer)[:2000]}")
        if run.dry_run:
            continue
        try:
            run.iris.add_note(cid, run.directory, answer_title(nid), hunt_note(run, prompt, question, answer))
        except Exception as exc:
            run.errors += 1
            run.log(f"ERROR case {cid}: could not write back: {exc}")


MODES = {"triage": triage, "summary": summary, "hunt": hunt}


def main(argv):
    modes = argv or ["triage"]
    unknown = [m for m in modes if m not in MODES]
    if unknown:
        sys.exit(f"unknown mode(s) {unknown}; use {sorted(MODES)}")
    run = Run()
    for m in modes:
        try:
            MODES[m](run)
        except Exception as exc:  # one mode failing (e.g. IRIS API change) must not stop the others
            run.errors += 1
            run.log(f"ERROR {m}: {exc}")
    run.log(f"done: {run.errors} error(s)")
    return 1 if run.errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
