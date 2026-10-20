#!/bin/bash
# Every test suite and check against the current checkouts, one Julia job at a time through the
# shared lock: TraitWorld (product setting and the test bed `all`), the acceptance suite (both),
# the four demonstrators, the documentation's examples. Logs to logs/<tag>/; a summary line each.
#     bash run_all.sh <tag>
R=/home/hellmann/Repos/julia-trait-bound
J=$R/julia-1.13/julia; FI=$R/julia-1.13/usr/lib/julia/facts/sys.so
L=$R/experiments/checks/logs/$1; mkdir -p $L
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
run() {  # name, dir, mode, args...
  local name=$1 dir=$2 mode=$3; shift 3
  local F=""; if [ $mode = all ]; then F="-J $FI"; export JULIA_DEPOT_PATH=/tmp/claude-1000/depot-facts:$HOME/.julia:; else unset JULIA_DEPOT_PATH; fi
  (cd $dir && flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 5400 $J $F --startup-file=no "$@" > $L/$name.log 2>&1); local rc=$?
  echo "$name rc=$rc  $(grep -E 'tests passed|of [0-9]+ checks pass|[0-9]+ pass, [0-9]+ fail|Test Failed|errored' $L/$name.log | tail -1)"
}
T='using Pkg; Pkg.test()'
run traitworld-product $R/TraitWorld plain --project=. -e "$T"
run traitworld-all     $R/TraitWorld all   --project=. -e "$T"
run acceptance-product $R/TraitWorld plain --project=. $R/experiments/facts/acceptance_compiler.jl
run acceptance-all     $R/TraitWorld all   --project=. $R/experiments/facts/acceptance_compiler.jl
for d in TraitTables TraitCSV TraitDifferentialEquations TraitMakie; do run $d $R/$d plain --project=. -e "$T"; done
for s in tutorial strict reference; do run doc-$s $R/TraitWorld plain --project=. $R/experiments/docs-examples/$s.jl; done
echo done
