#!/bin/bash
# E-262 (3): Base's subtype, core, ambiguous and worlds test files on a built tree, one run each, wall time
# per file; then detect_ambiguities(Base). 4 cores, niced, one file at a time.
#     experiments/unification/e262_suites.sh <julia tree> <label>
R=${TW_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
T=$(cd "$R/$1" && pwd); L=$2
for t in subtype core ambiguous worlds; do
  s=$(date +%s.%N)
  nice -n 10 "$T/julia" --startup-file=no -e "Base.runtests([\"$t\"]; ncores=1)" > "$R/experiments/unification/logs/e262-$L-$t.log" 2>&1; rc=$?
  e=$(date +%s.%N)
  printf "%s %-10s exit %d  wall %.1f s  %s\n" "$L" "$t" $rc $(echo "$e - $s" | bc) "$(grep -E 'SUCCESS|FAILURE|Test Summary' "$R/experiments/unification/logs/e262-$L-$t.log" | tail -1)"
done
nice -n 10 "$T/julia" --startup-file=no -e 'using Test; a = Test.detect_ambiguities(Base); println("detect_ambiguities(Base): ", length(a))' 2>&1 | tail -1 | sed "s/^/$L /"
