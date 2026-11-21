"""Contract checks for the event catalogue (EA-007 §8, contracts/events/).

Run: python3 -m pytest -q tests/contracts
Needs: pytest, jsonschema>=4.18 (with `referencing`), PyYAML.
"""
from __future__ import annotations

import json
import re
import uuid
from pathlib import Path

import pytest

jsonschema = pytest.importorskip("jsonschema")
yaml = pytest.importorskip("yaml")
referencing = pytest.importorskip("referencing")

ROOT = Path(__file__).resolve().parents[2]
EVENTS = ROOT / "contracts" / "events"
EA007 = ROOT / "docs" / "04_enterprise_architecture" / "EA-007_event_architecture_and_process_workflows.md"
MODULES = {"TENANT", "IDENTITY", "WORKFLOW", "DOCUMENTS", "SECURITY_MASTER", "PRODUCT", "INVESTMENT", "PORTFOLIO",
           "OMS", "EXECUTION", "SETTLEMENT", "COMPLIANCE", "RISK", "ACCOUNTING", "VALUATION", "NAV", "OPERATIONS",
           "INVESTOR", "DISTRIBUTION", "FINANCE", "REPORTING", "AI"}
MASTER_PROMPT_EXAMPLES = {"ORDER_CREATED", "ORDER_VALIDATED", "ORDER_APPROVED", "TRADE_EXECUTED", "TRADE_SETTLED",
                          "HOLDINGS_UPDATED", "COMPLIANCE_BREACH_DETECTED", "NAV_CALCULATED", "NAV_APPROVED",
                          "INVESTOR_TRANSACTION_RECEIVED", "DISTRIBUTOR_FLOW_UPDATED", "RECONCILIATION_EXCEPTION_CREATED"}
# Field names that would carry investor or employee personal data (EA-007 rule E9).
PII_WORDS = re.compile(r"(^|_)(pan|name|email|mobile|phone|address|dob|birth|aadhaar|bank_account|ifsc|nominee)(_|$)")


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


CATALOGUE = yaml.safe_load((EVENTS / "catalogue.yaml").read_text(encoding="utf-8"))
ENTRIES = CATALOGUE["events"]
SCHEMA_FILES = sorted(p for p in EVENTS.glob("*.schema.json"))
REGISTRY = referencing.Registry().with_resources(
    (load(p)["$id"], referencing.Resource.from_contents(load(p))) for p in SCHEMA_FILES)


def walk(node, path=""):
    if isinstance(node, dict):
        yield path, node
        for k, v in node.items():
            yield from walk(v, f"{path}/{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk(v, f"{path}/{i}")


def test_every_schema_is_valid_draft_2020_12():
    for p in SCHEMA_FILES:
        jsonschema.Draft202012Validator.check_schema(load(p))


def test_catalogue_and_files_match_one_to_one():
    names = [e["name"] for e in ENTRIES]
    assert len(names) == len(set(names)), "duplicate event name in catalogue"
    files = {p.name for p in SCHEMA_FILES} - {"envelope.v1.schema.json", "common.v1.schema.json"}
    assert files == {e["schema"] for e in ENTRIES}


@pytest.mark.parametrize("entry", ENTRIES, ids=lambda e: e["name"])
def test_entry_metadata(entry):
    assert re.fullmatch(r"[A-Z][A-Z0-9_]*", entry["name"])
    assert entry["schema"] == f"{entry['name']}.v{entry['version']}.schema.json"
    assert entry["producer"] in MODULES
    assert set(entry["consumers"]) <= MODULES | {"L4_SIGNAL_BRIDGE"}
    assert entry["producer"] not in entry["consumers"], "a module does not consume its own event"
    meta = load(EVENTS / entry["schema"])["x-amc-os"]
    assert meta["event_type"] == entry["name"] and meta["event_version"] == entry["version"]
    assert meta["producer"] == entry["producer"] and meta["aggregate_type"] == entry["aggregate_type"]
    assert meta["data_classification"] in {"INTERNAL", "CONFIDENTIAL"}


def test_master_prompt_example_events_present():
    assert MASTER_PROMPT_EXAMPLES <= {e["name"] for e in ENTRIES}


def test_no_binary_numbers_and_no_personal_data_fields():
    for p in SCHEMA_FILES:
        for where, node in walk(load(p)):
            assert node.get("type") != "number", f"{p.name}{where}: use decimal_string, never JSON numbers"
            for field in node.get("properties", {}) if isinstance(node.get("properties"), dict) else {}:
                assert not PII_WORDS.search(field), f"{p.name}{where}: field '{field}' looks like personal data"
                if p.name != "envelope.v1.schema.json":
                    assert field != "tenant_id", f"{p.name}: tenant_id belongs only in the envelope"


def _example(schema: dict, resolver=None):
    """Smallest instance with every required field, built from the schema (no invented business values)."""
    resolver = resolver or REGISTRY.resolver(schema.get("$id", ""))
    if "$ref" in schema:
        resolved = resolver.lookup(schema["$ref"])
        return _example(resolved.contents, resolved.resolver)
    if "const" in schema:
        return schema["const"]
    if "enum" in schema:
        return schema["enum"][0]
    t = schema.get("type")
    if t == "object":
        return {k: _example(schema["properties"][k], resolver) for k in schema.get("required", [])}
    if t == "array":
        return [_example(schema["items"], resolver) for _ in range(schema.get("minItems", 0))]
    if t == "integer":
        return max(schema.get("minimum", 0), 1)
    if t == "boolean":
        return False
    if t == "string":
        fmt, pat = schema.get("format"), schema.get("pattern", "")
        if fmt == "uuid":
            return str(uuid.UUID(int=1))
        if fmt == "date-time":
            return "2026-11-20T18:35:02+05:30"
        if fmt == "date":
            return "2026-11-20"
        samples = {"RULE-": "RULE-EXAMPLE@v1", "FE-": "FE-01@1.0.0", "[A-Z]{3}$": "INR", "{64}": "0" * 64,
                   "{9}[0-9]": "INE000A01010", "/WF-": f"{uuid.UUID(int=1)}/WF-007/2026-11-20", "?(0|": "1.25",
                   "^[A-Z][A-Z0-9_]*$": "NAV_APPROVED"}
        for key, value in samples.items():
            if key in pat:
                return value
        return "EXAMPLE_CODE"
    raise AssertionError(f"no example rule for {schema}")


@pytest.mark.parametrize("entry", ENTRIES, ids=lambda e: e["name"])
def test_example_envelope_validates(entry):
    payload_schema = load(EVENTS / entry["schema"])
    envelope_schema = load(EVENTS / "envelope.v1.schema.json")
    payload = _example(payload_schema)
    envelope = _example(envelope_schema) | {"event_type": entry["name"], "event_version": entry["version"],
                                            "producer": entry["producer"], "aggregate_type": entry["aggregate_type"],
                                            "data_classification": entry["data_classification"], "payload": payload}
    jsonschema.Draft202012Validator(envelope_schema, registry=REGISTRY).validate(envelope)
    jsonschema.Draft202012Validator(payload_schema, registry=REGISTRY).validate(payload)
    bad = dict(payload, unexpected_field="x")
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.Draft202012Validator(payload_schema, registry=REGISTRY).validate(bad)


def test_ea007_catalogue_table_lists_exactly_the_catalogue():
    text = EA007.read_text(encoding="utf-8")
    listed = set(re.findall(r"^\| `([A-Z][A-Z0-9_]*)\.v1` \|", text, re.M))
    assert listed == {e["name"] for e in ENTRIES}
