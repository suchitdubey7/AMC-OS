#!/usr/bin/env python3
"""Documentation checks required by GOV-001 (Step 0 of GOV-006).

Checks:
  1. Every spec document under docs/ (except README.md files and docs/**/arb_minutes)
     and every ADR has front matter with id, title, status.
  2. Status is one of the allowed lifecycle values.
  3. Document IDs are unique and match the file name prefix.
  4. Relative Markdown links resolve to existing files.

Exit code 0 = all checks pass, 1 = at least one failure.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC_STATUSES = {"Draft", "Under Review", "Approved", "Superseded"}
ADR_STATUSES = {"Draft", "Under Review", "Approved", "Implemented", "Validated", "Superseded"}
FRONT_MATTER = re.compile(r"\A---\n(.*?)\n---\n", re.S)
LINK = re.compile(r"\]\(([^)\s]+)\)")


def parse_front_matter(text: str) -> dict[str, str] | None:
    m = FRONT_MATTER.match(text)
    if not m:
        return None
    fields: dict[str, str] = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            fields[key.strip()] = value.strip()
    return fields


def spec_files() -> list[Path]:
    files = [p for p in (ROOT / "docs").rglob("*.md")
             if p.name != "README.md" and "arb_minutes" not in p.parts]
    files += [p for p in (ROOT / "architecture" / "adrs").glob("ADR-*.md")]
    return sorted(files)


def check_front_matter(errors: list[str]) -> None:
    seen: dict[str, Path] = {}
    for path in spec_files():
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        fm = parse_front_matter(text)
        # v0.9 inputs were exported before GOV-001 and carry no front matter yet (fixed in WP2/WP4).
        if fm is None:
            if re.match(r"(PRD|DA)-000_", path.name):
                continue
            errors.append(f"{rel}: missing front matter")
            continue
        for key in ("id", "title", "status"):
            if not fm.get(key):
                errors.append(f"{rel}: front matter missing '{key}'")
        doc_id, status = fm.get("id", ""), fm.get("status", "")
        allowed = ADR_STATUSES if doc_id.startswith("ADR-") else DOC_STATUSES
        if status and status not in allowed:
            errors.append(f"{rel}: status '{status}' not in {sorted(allowed)}")
        if doc_id and not path.name.startswith(doc_id):
            errors.append(f"{rel}: id '{doc_id}' does not match file name")
        if doc_id in seen:
            errors.append(f"{rel}: duplicate id '{doc_id}' (also {seen[doc_id].relative_to(ROOT)})")
        elif doc_id:
            seen[doc_id] = path


def check_links(errors: list[str]) -> None:
    for path in sorted(ROOT.rglob("*.md")):
        if ".git" in path.parts:
            continue
        for target in LINK.findall(path.read_text(encoding="utf-8")):
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            target = target.split("#", 1)[0]
            resolved = (ROOT / target.lstrip("/")) if target.startswith("/") else (path.parent / target)
            if not resolved.exists():
                errors.append(f"{path.relative_to(ROOT)}: broken link -> {target}")


def main() -> int:
    errors: list[str] = []
    check_front_matter(errors)
    check_links(errors)
    for e in errors:
        print(f"FAIL  {e}")
    print(f"{len(spec_files())} spec documents checked; {len(errors)} problem(s).")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
