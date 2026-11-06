#!/bin/bash
# The unification gates (stage 1: m1_*, stage 2: m2_*) on a built tree; one Julia process per gate.
# Usage: experiments/unification/gates/run_all.sh <julia tree> [pattern]    e.g. julia-unified 'm[12]_*'
R=${TW_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
T=$(cd "$R" && cd "$1" && pwd); P=${2:-m[12]_*}
U=$R/experiments/unification
pass=0; fail=0
for g in $U/gates/$P.jl; do
  out=$(nice -n 10 "$T/julia" --startup-file=no --project="$U" "$g" 2>&1); rc=$?
  if [ $rc = 0 ]; then pass=$((pass+1)); echo "PASS $(basename $g)"; else fail=$((fail+1)); echo "FAIL $(basename $g) (exit $rc)"; echo "$out" | tail -15 | sed 's/^/    /'; fi
done
echo "gates: $pass passed, $fail failed"
