# contracts/events

Versioned event catalogue (GOV-001 §4: `<NAME>.v<n>`). Status: **Draft** — designed in [EA-007](/docs/04_enterprise_architecture/EA-007_event_architecture_and_process_workflows.md) (WP3 / Step 13); nothing here is Approved.

| File | What it is |
| --- | --- |
| `envelope.v1.schema.json` | The envelope every event has (EA-007 §3) |
| `common.v1.schema.json` | Shared types: UUID, dates, decimal strings, money, rule and engine version references, workflow ID |
| `<NAME>.v1.schema.json` | The payload of one event (103 events) |
| `catalogue.yaml` | Machine-readable list: producer, aggregate, class, data classification, consumers. Twin of EA-007 §8 |

Each schema's `x-amc-os` block names the producer, aggregate, class and data classification, and for events with money or quantity figures their `figure_source` (EA-007 rule E7). Changes inside a version (optional fields added, EA-007 rule V1) are listed under `changes:` in `catalogue.yaml`.

Rules (EA-007 §2, §6): only the owning module publishes; money and quantities are decimal strings, never JSON numbers; no personal data; adding an optional field keeps the version, any other change is a new version published side by side for at least one release.

Checks: `python3 -m pytest -q tests/contracts` (needs `pytest`, `jsonschema`, `PyYAML`).
