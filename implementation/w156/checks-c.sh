#!/bin/bash
# W-156, third part: the checks of the brief on a built tree, one job at a time: the gates, Base's test files,
# the demonstrators' suites and sessions, NetworkDynamics' subset, the forks' digests, the examples.
#     bash experiments/implementation/w156/checks-c.sh <julia tree> <label>
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
bash "$R/experiments/implementation/gates/run_all.sh" "$1" > "$H/logs/c-$2-gates.log" 2>&1
grep -E '^gates:|^stage gates:|^FAIL' "$H/logs/c-$2-gates.log" | tee -a "$H/logs/c-$2-summary.log"
bash "$H/base-c.sh" "$1" "$2"
bash "$H/suites-tree.sh" "$1" "$2" tables csv report report-session makie makie-session tde tde-session forks-tables digests examples
bash "$H/suites-c.sh" "$1" "$2" nd
echo "CHECKS DONE"
