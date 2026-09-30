#!/usr/bin/env bash
# Runs the script tests against the real sources, with the openmw API faked out (stubs.lua).
#
#   bash Sources/Tools/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")"
status=0
for test in test_*.lua; do
    printf '%-18s ' "$test"
    if ! lua "$test"; then status=1; fi
done
exit $status
