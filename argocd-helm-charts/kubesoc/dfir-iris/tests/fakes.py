"""Fake IRIS, Ollama and MISP APIs on one local HTTP server (stdlib only)."""
import json
import threading
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class State:
    def __init__(self):
        self.alerts = []
        self.cases = {}        # cid -> case detail dict
        self.list_fields = ("case_id", "case_name", "case_close_date", "client_name")
        self.iocs = {}         # cid -> [ioc]
        self.assets = {}
        self.timeline = {}
        self.dirs = {}         # cid -> [{id, name, notes: [{id, title}]}]
        self.notes = {}        # note id -> {note_title, note_content, cid}
        self.next_id = 100
        self.alert_updates = []
        self.case_updates = []
        self.ollama_requests = []
        self.ollama_answers = {}   # mode -> dict or exception text
        self.misp_attributes = []  # values MISP knows
        self.misp_sightings = []
        self.misp_events = []
        self.requests = []

    def add_note(self, cid, directory, title, content):
        self.next_id += 1
        d = next((d for d in self.dirs.setdefault(cid, []) if d["name"] == directory), None)
        if d is None:
            self.next_id += 1
            d = {"id": self.next_id, "name": directory, "notes": [], "subdirectories": []}
            self.dirs[cid].append(d)
        nid = self.next_id + 1000
        d["notes"].append({"id": nid, "title": title})
        self.notes[nid] = {"note_title": title, "note_content": content, "cid": cid, "directory": directory}
        return nid

    def notes_in(self, cid, directory):
        return [self.notes[n["id"]] for d in self.dirs.get(cid, []) if d["name"] == directory for n in d["notes"]]


def mode_of(schema):
    props = schema.get("properties", {})
    if "severity" in props:
        return "triage"
    if "recommended_actions" in props:
        return "summary"
    return "hunt"


def make_handler(state):
    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def reply(self, obj, code=200):
            raw = json.dumps(obj).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def ok(self, data):
            self.reply({"status": "success", "message": "", "data": data})

        def body(self):
            n = int(self.headers.get("Content-Length") or 0)
            return json.loads(self.rfile.read(n)) if n else None

        def do_GET(self):
            self.route("GET")

        def do_POST(self):
            self.route("POST")

        def route(self, method):
            u = urllib.parse.urlparse(self.path)
            q = dict(urllib.parse.parse_qsl(u.query))
            p = u.path
            body = self.body() if method == "POST" else None
            state.requests.append((method, p, q, body, dict(self.headers)))
            cid = int(q["cid"]) if "cid" in q else None
            # --- Ollama
            if p == "/api/chat":
                state.ollama_requests.append(body)
                ans = state.ollama_answers.get(mode_of(body["format"]))
                if isinstance(ans, str):
                    return self.reply({"error": ans}, 500)
                return self.reply({"message": {"role": "assistant", "content": json.dumps(ans)},
                                   "eval_count": 42, "done": True})
            # --- MISP
            if p == "/attributes/restSearch":
                vals = set(body["value"])
                return self.reply({"response": {"Attribute": [
                    {"id": i, "value": v} for i, v in enumerate(state.misp_attributes)
                    if v in vals or any(part in vals for part in v.split("|"))]}})
            if p == "/sightings/add":
                state.misp_sightings.append(body)
                return self.reply({"saved": True, "success": True})
            if p == "/events/add":
                state.misp_events.append(body)
                return self.reply({"Event": {"id": "1"}})
            # --- IRIS
            if p == "/alerts/filter":
                return self.ok({"alerts": [a for a in state.alerts if a.get("alert_status_id", 2) == 2]})
            if p.startswith("/alerts/update/"):
                aid = int(p.rsplit("/", 1)[1])
                state.alert_updates.append((aid, body))
                for a in state.alerts:
                    if a["alert_id"] == aid:
                        a["alert_note"], a["alert_tags"] = body["alert_note"], body["alert_tags"]
                return self.ok({})
            if p == "/manage/cases/list":
                return self.ok([{k: c.get(k) for k in state.list_fields if k in c} for c in state.cases.values()])
            if p.startswith("/manage/cases/update/"):
                c = int(p.rsplit("/", 1)[1])
                state.case_updates.append((c, body))
                state.cases[c]["case_tags"] = body["case_tags"]
                return self.ok({})
            if p.startswith("/manage/cases/"):
                return self.ok(state.cases[int(p.rsplit("/", 1)[1])])
            if p == "/case/ioc/list":
                return self.ok({"ioc": state.iocs.get(cid, []), "state": {}})
            if p == "/case/assets/list":
                return self.ok({"assets": state.assets.get(cid, []), "state": {}})
            if p == "/case/timeline/events/list":
                return self.ok({"timeline": state.timeline.get(cid, []), "state": {}})
            if p == "/case/notes/directories/filter":
                return self.ok(state.dirs.get(cid, []))
            if p == "/case/notes/directories/add":
                state.next_id += 1
                d = {"id": state.next_id, "name": body["name"], "notes": [], "subdirectories": []}
                state.dirs.setdefault(cid, []).append(d)
                return self.ok({"id": d["id"], "name": d["name"]})
            if p == "/case/notes/add":
                d = next(d for d in state.dirs[cid] if d["id"] == body["directory_id"])
                nid = state.add_note(cid, d["name"], body["note_title"], body["note_content"])
                return self.ok({"note_id": nid})
            if p.startswith("/case/notes/"):
                n = state.notes[int(p.rsplit("/", 1)[1])]
                return self.ok({"note_title": n["note_title"], "note_content": n["note_content"]})
            return self.reply({"status": "error", "message": f"no route {method} {p}"}, 404)
    return H


class FakeServer:
    def __init__(self):
        self.state = State()
        self.httpd = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(self.state))
        self.url = f"http://127.0.0.1:{self.httpd.server_address[1]}"
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()

    def close(self):
        self.httpd.shutdown()
        self.httpd.server_close()
