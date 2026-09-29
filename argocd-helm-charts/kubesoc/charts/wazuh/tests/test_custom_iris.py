"""Unit tests for files/custom-iris.py (the Wazuh -> DFIR-IRIS integration).

    pytest argocd-helm-charts/kubesoc/wazuh/tests
"""
import importlib.util
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("custom_iris", HERE.parent / "files" / "custom-iris.py")
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)

ALERT = {
    "id": "1700000000.123",
    "timestamp": "2025-12-10T01:02:02.000+0100",
    "rule": {"id": "99904", "level": 9, "description": "sshd: failed from malicious IP",
             "groups": ["syslog", "sshd"], "mitre": {"id": ["T1110"]}},
    "agent": {"id": "001", "name": "web1", "ip": "192.0.2.10",
              "labels": {"tenant": "001"}, "os": {"platform": "ubuntu"}},
    "data": {"srcip": "203.0.113.66"},
    "syscheck": {"sha256_after": "ab" * 32, "path": "/tmp/x"},
    "full_log": "Dec 10 01:02:02 web1 sshd[1]: Failed password for root from 203.0.113.66",
}


def test_severity_mapping():
    assert [ci.severity_id(l) for l in (0, 4, 5, 7, 8, 11, 12, 13, 14, 15)] == [3, 3, 4, 4, 1, 1, 5, 5, 6, 6]


def test_asset_type():
    assert ci.asset_type_id({"os": {"platform": "windows"}}) == ci.ASSET_WINDOWS
    assert ci.asset_type_id({"os": {"platform": "darwin"}}) == ci.ASSET_MAC
    assert ci.asset_type_id({"os": {"uname": "Linux host 6.1"}}) == ci.ASSET_LINUX
    assert ci.asset_type_id({}) == ci.ASSET_OTHER


def test_collect_iocs_dedups():
    alert = dict(ALERT, data={"srcip": "203.0.113.66", "dstip": "203.0.113.66"})
    iocs = ci.collect_iocs(alert)
    values = [(i["ioc_type_id"], i["ioc_value"]) for i in iocs]
    assert (ci.IOC_TYPES["ip-src"], "203.0.113.66") in values
    assert (ci.IOC_TYPES["ip-dst"], "203.0.113.66") in values
    assert (ci.IOC_TYPES["sha256"], "ab" * 32) in values
    assert len(values) == len(set(values))
    assert all(i["ioc_description"] == "From Wazuh rule 99904" for i in iocs)


def test_build_alert_fixed_customer():
    calls = []

    def resolve(name):
        calls.append(name)
        return 7

    p = ci.build_alert(ALERT, {"customer_name": "Tenant 001"}, resolve)
    assert calls == ["Tenant 001"]
    assert p["alert_customer_id"] == 7
    assert p["alert_severity_id"] == 1
    assert p["alert_source_event_time"] == "2025-12-10T00:02:02"
    assert "rule:99904" in p["alert_tags"] and "tenant:001" in p["alert_tags"] and "mitre:T1110" in p["alert_tags"]
    assert p["alert_assets"][0]["asset_type_id"] == ci.ASSET_LINUX


def test_build_alert_customer_map_and_default():
    assert ci.build_alert(ALERT, {"customer_map": {"001": 3}})["alert_customer_id"] == 3
    assert ci.build_alert(ALERT, {})["alert_customer_id"] == 1
    bad = dict(ALERT, timestamp="yesterday")
    assert "alert_source_event_time" not in ci.build_alert(bad, {})
