#!/usr/bin/env python3
"""Merge gate for the build loop (CR-0001, GOV-008 §5).

Decides, with fixed rules, whether the build loop may merge a branch into main
without the project owner. Fails closed: anything unclear means "do not merge".

Usage:
  python3 scripts/merge_gate.py --base main --head <branch> [--ci success|failure|pending|unknown]

Exit code 0 = PASS (loop may merge), 1 = FAIL (owner must merge), 2 = usage error.
Rules:
  G1  head is directly on top of base (fast-forwardable; only the next branch in the chain)
  G2  no changed path is owned in .github/CODEOWNERS, except table-row-only edits to the
      GOV-001 register and GOV-006 plan, plus reviews/** and LOOP_STATE.md
  G3  every changed spec document under docs/ still has status Draft
  G4  the branch adds or changes a review file reviews/STEP-*_round*.md; the highest round
      has verdict RECOMMEND MERGE or RECOMMEND MERGE AFTER FIXES and no Blocker/Major rows
  G5  scripts/check_docs.py passes on the head
  G6  GitHub CI for the head is not failed or pending (unknown is allowed only because
      G5 re-runs the same documentation checks locally; database/ is protected by G2)
"""
from __future__ import annotations

import argparse
import fnmatch
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ALWAYS_ALLOWED = ("reviews/", "LOOP_STATE.md")
TABLE_ONLY_ALLOWED = (
    "docs/00_governance/GOV-001_document_control_and_identifiers.md",
    "docs/00_governance/GOV-006_gap_analysis_and_delivery_plan.md",
)
OK_VERDICTS = {"RECOMMEND MERGE", "RECOMMEND MERGE AFTER FIXES"}


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def owned_patterns() -> list[str]:
    path = ROOT / ".github" / "CODEOWNERS"
    patterns = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            patterns.append(line.split()[0])
    return patterns


def is_owned(path: str, patterns: list[str]) -> bool:
    p = "/" + path
    for pat in patterns:
        if pat.endswith("/"):
            if p.startswith(pat):
                return True
        elif fnmatch.fnmatch(p, pat):
            return True
    return False


def table_only_change(base: str, head: str, path: str) -> bool:
    diff = git("diff", "--unified=0", f"{base}...{head}", "--", path)
    for line in diff.splitlines():
        if line.startswith(("+++", "---", "@@", "diff ", "index ", "new file", "deleted file")):
            continue
        if line.startswith(("+", "-")):
            body = line[1:].strip()
            if body and not body.startswith("|"):
                return False
    return True


def front_matter_status(text: str) -> str | None:
    m = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None
    for line in m.group(1).splitlines():
        if line.startswith("status:"):
            return line.split(":", 1)[1].strip()
    return None


def check_review(head: str, changed: list[str]) -> tuple[bool, str]:
    reviews = [c for c in changed if re.fullmatch(r"reviews/STEP-[0-9A-Za-z]+_round(\d+)\.md", c)]
    if not reviews:
        return False, "no review file reviews/STEP-*_round*.md in this branch"
    latest = max(reviews, key=lambda c: int(re.search(r"_round(\d+)\.md$", c).group(1)))
    text = git("show", f"{head}:{latest}")
    m = re.search(r"\*\*Verdict \(advisory\):\*\*\s*([A-Z ]+?)\s*(?:\n|$)", text)
    if not m:
        return False, f"{latest}: verdict line not found"
    verdict = m.group(1).strip()
    if verdict not in OK_VERDICTS:
        return False, f"{latest}: verdict is {verdict}"
    serious = re.findall(r"^\|\s*\d+\s*\|\s*(Blocker|Major)\s*\|", text, re.M | re.I)
    if serious:
        return False, f"{latest}: {len(serious)} Blocker/Major finding(s) listed"
    return True, f"{latest}: {verdict}, no Blocker/Major"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--head", required=True)
    ap.add_argument("--ci", default="unknown", choices=["success", "failure", "pending", "unknown"])
    a = ap.parse_args()

    results: list[tuple[str, bool, str]] = []

    base_sha = git("rev-parse", a.base).strip()
    mb = git("merge-base", a.base, a.head).strip()
    results.append(("G1 next in chain", mb == base_sha,
                    "head is directly on base" if mb == base_sha else "head is not on top of base"))

    changed = [c for c in git("diff", "--name-only", f"{a.base}...{a.head}").splitlines() if c]
    patterns = owned_patterns()
    blocked = []
    for c in changed:
        if c.startswith(ALWAYS_ALLOWED):
            continue
        if c in TABLE_ONLY_ALLOWED and table_only_change(a.base, a.head, c):
            continue
        if is_owned(c, patterns):
            blocked.append(c)
    results.append(("G2 no owner-only files", not blocked,
                    "ok" if not blocked else "owner-only: " + ", ".join(blocked)))

    bad_status = []
    for c in changed:
        if c.startswith("docs/") and c.endswith(".md") and not c.endswith("README.md"):
            try:
                text = git("show", f"{a.head}:{c}")
            except subprocess.CalledProcessError:
                continue  # deleted file; G2 decides
            st = front_matter_status(text)
            if st is not None and st != "Draft":
                bad_status.append(f"{c} ({st})")
    results.append(("G3 documents stay Draft", not bad_status,
                    "ok" if not bad_status else ", ".join(bad_status)))

    ok, msg = check_review(a.head, changed)
    results.append(("G4 independent review clean", ok, msg))

    current = git("rev-parse", "--abbrev-ref", "HEAD").strip()
    head_sha = git("rev-parse", a.head).strip()
    if git("rev-parse", "HEAD").strip() != head_sha:
        results.append(("G5 check_docs.py", False, f"checked-out commit is not {a.head} (on {current})"))
    else:
        r = subprocess.run([sys.executable, str(ROOT / "scripts" / "check_docs.py")], capture_output=True, text=True)
        results.append(("G5 check_docs.py", r.returncode == 0, r.stdout.strip().splitlines()[-1] if r.stdout else "no output"))

    results.append(("G6 GitHub CI", a.ci in ("success", "unknown"), f"CI status: {a.ci}"))

    passed = all(ok for _, ok, _ in results)
    print(f"MERGE GATE {'PASS' if passed else 'FAIL'}  base={a.base} head={a.head} ({head_sha[:7]})")
    for name, ok, msg in results:
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}: {msg}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
