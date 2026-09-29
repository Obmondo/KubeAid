"""Unit tests for files/wazuh-cdb-export.py (MISP indicators -> Wazuh CDB lists).

    pytest argocd-helm-charts/kubesoc/misp/tests
"""
import importlib.util
import json
import os
import pathlib

HERE = pathlib.Path(__file__).resolve().parent


def load(monkeypatch, **env):
    base = {"MISP_URL": "https://misp.example.com/", "MISP_KEY": "k",
            "LISTS": json.dumps([{"name": "misp-malicious-ip", "types": ["ip-src"]}])}
    base.update(env)
    for k, v in base.items():
        monkeypatch.setenv(k, v)
    spec = importlib.util.spec_from_file_location("cdb_export", HERE.parent / "files" / "wazuh-cdb-export.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_cdb_line_quotes_what_wazuh_needs(monkeypatch):
    m = load(monkeypatch)
    assert m.cdb_line("203.0.113.66", "") == "203.0.113.66:"
    # IPv6: the key holds ":" and must be quoted, or Wazuh rejects the whole file.
    assert m.cdb_line("2001:db8::1", "") == '"2001:db8::1":'
    assert m.cdb_line("bad.example.com", "misp:1") == 'bad.example.com:"misp:1"'
    assert m.CDB_LINE.match(m.cdb_line("2001:db8::1", "a:b"))


def test_cdb_line_rejects_unrepresentable(monkeypatch):
    m = load(monkeypatch)
    assert m.cdb_line('bad"quote', "") is None


def test_targets_single_manager(monkeypatch):
    m = load(monkeypatch, WAZUH_URL="https://wazuh.example.com:55000/", WAZUH_USER="u", WAZUH_PASS="p",
             WAZUH_VERIFY_TLS="false")
    (t,) = m.targets()
    assert t["url"] == "https://wazuh.example.com:55000"
    assert (t["user"], t["password"]) == ("u", "p")
    assert t["ctx"].check_hostname is False


def test_targets_per_tenant(monkeypatch, tmp_path):
    for name in ("001", "002"):
        d = tmp_path / name
        d.mkdir()
        (d / "API_USERNAME").write_text("wazuh-wui\n")
        (d / "API_PASSWORD").write_text("pw-%s\n" % name)
    targets = json.dumps([{"name": "001", "url": "https://wazuh.wazuh-001.svc:55000", "verifyTls": False},
                          {"name": "002", "url": "https://wazuh.wazuh-002.svc:55000/"}])
    m = load(monkeypatch, WAZUH_TARGETS=targets, WAZUH_CREDS_DIR=str(tmp_path))
    got = m.targets()
    assert [t["name"] for t in got] == ["001", "002"]
    assert got[1]["password"] == "pw-002"
    assert got[1]["url"].endswith(":55000")
    assert got[0]["ctx"].check_hostname is False and got[1]["ctx"].check_hostname is True
    os.environ.pop("WAZUH_TARGETS", None)
