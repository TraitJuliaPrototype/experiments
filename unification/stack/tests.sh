#!/bin/bash
# Base test files on a built tree, one at a time, one core, niced: the checks of the restructured
# `unified` stack (julia-changes.md §7). Logs: experiments/unification/stack/logs/<label>-<test>.log
#     experiments/unification/stack/tests.sh <julia tree> <label> <test>...
R=${TW_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
T=$(cd "$R/$1" && pwd); L=$2; shift 2
D=$R/experiments/unification/stack/logs; mkdir -p $D
for t in "$@"; do
  s=$(date +%s.%N)
  f=$D/$L-$(echo $t | tr / _).log
  nice -n 10 "$T/julia" --startup-file=no -e "Base.runtests([\"$t\"]; ncores=1)" > "$f" 2>&1; rc=$?
  e=$(date +%s.%N)
  printf "%s %-20s exit %d  wall %.1f s  %s\n" "$L" "$t" $rc $(echo "$e - $s" | bc) "$(grep -E 'SUCCESS|FAILURE' "$f" | tail -1)"
done
