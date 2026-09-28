"""Unit tests for files/ai-triage.py (IRIS alert triage by the local model).

    pytest argocd-helm-charts/dfir-iris/tests
"""
import importlib.util
import json
import pathlib

import pytest

HERE = pathlib.Path(__file__).resolve().parent
SCRIPT = HERE.parent / "files" / "ai-triage.py"
PROMPT = HERE.parents[1] / "kubesoc-content" / "ai" / "prompts" / "triage-system.txt"


def load(monkeypatch, **env):
    for k, v in env.items():
        monkeypatch.setenv(k, v)
    spec = importlib.util.spec_from_file_location("ai_triage", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_rule_level(monkeypatch):
    m = load(monkeypatch)
    assert m.rule_level({"alert_source_content": {"rule": {"level": 12}}}) == 12
    assert m.rule_level({"alert_tags": "wazuh,level:9"}) == 9
    assert m.rule_level({}) is None


def test_trimmed_caps_size(monkeypatch):
    m = load(monkeypatch)
    alert = {"alert_title": "t", "alert_description": "d" * 5000,
             "alert_source_content": {"rule": {"id": "1"}, "full_log": "x" * 5000, "secret": "not sent"},
             "iocs": [{"ioc_type": {"type_name": "ip-src"}, "ioc_value": "203.0.113.66"}] * 30}
    text = m.trimmed(alert)
    assert len(text) <= 6000
    view = json.loads(text) if len(text) < 6000 else None
    if view:
        assert "secret" not in view["wazuh_alert"]
        assert len(view["iocs"]) == 20


def test_ask_model_rejects_answers_outside_the_schema(monkeypatch):
    m = load(monkeypatch)
    answer = {"severity": "extreme", "false_positive": "likely", "category": "x", "summary": "s",
              "next_action": "n", "confidence": 0.5}
    monkeypatch.setattr(m, "http", lambda *a, **k: {"message": {"content": json.dumps(answer)}})
    with pytest.raises(ValueError):
        m.ask_model("http://ollama", "model", 5, "{}")
    answer["severity"] = "high"
    got, _, _ = m.ask_model("http://ollama", "model", 5, "{}")
    assert got["severity"] == "high"


def test_prompt_file_matches_the_built_in_prompt(monkeypatch):
    """The content package's prompt and the script's default must not drift."""
    m = load(monkeypatch)
    assert PROMPT.read_text(encoding="utf-8").strip() == m.SYSTEM


def test_prompt_file_overrides(monkeypatch, tmp_path):
    p = tmp_path / "prompt.txt"
    p.write_text("custom prompt\n")
    m = load(monkeypatch, TRIAGE_SYSTEM_PROMPT_FILE=str(p))
    assert m.SYSTEM == "custom prompt"
