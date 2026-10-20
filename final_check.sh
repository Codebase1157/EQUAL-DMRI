#!/usr/bin/env bash
# Full pre-submission gate.
#
# The audit found two faults in the build's own checks: audit.py always exited
# zero, and final_check.sh ignored failures inside pipes, so a failed audit could
# not stop the build. Both are fixed: audit.py returns a real exit code, and
# `set -euo pipefail` below makes a failure anywhere in a pipeline fail the run.
set -euo pipefail

echo "=== tests ==="
python -m pytest tests/ -q

echo
echo "=== result store ==="
python scripts/init_results.py

echo
echo "=== split manifests ==="
python scripts/make_splits.py > /dev/null && echo "manifests written and checked"

echo
echo "=== tables ==="
python scripts/build_tables.py --out docs/TABLES.md

echo
echo "=== build audit (strict: placeholders fail) ==="
python audit/audit.py --strict

echo
echo "ALL CHECKS PASSED - ready to submit"
