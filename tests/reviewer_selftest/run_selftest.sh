#!/usr/bin/env bash
# Prepares a throw-away local branch with the planted-defect fixture for the reviewer self-test.
# Usage: tests/reviewer_selftest/run_selftest.sh   (then run the reviewer on branch selftest-reviewer vs main)
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
cd "$root"
git worktree remove --force /tmp/selftest_wt 2>/dev/null || true
git branch -D selftest-reviewer 2>/dev/null || true
git worktree add -q -b selftest-reviewer /tmp/selftest_wt HEAD
cp tests/reviewer_selftest/PS-090_selftest_fixture.md.txt /tmp/selftest_wt/docs/01_product_strategy/PS-090_selftest_fixture.md
git -C /tmp/selftest_wt add -A
git -C /tmp/selftest_wt -c user.name=selftest -c user.email=selftest@example.invalid commit -q -m "Reviewer self-test fixture (do not push)"
echo "Ready: branch selftest-reviewer (worktree /tmp/selftest_wt). Review: git diff HEAD...selftest-reviewer"
echo "Never push this branch."
