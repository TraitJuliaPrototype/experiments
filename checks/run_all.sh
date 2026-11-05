#!/bin/bash
# Every test suite and check against the current checkouts, each job in a slot of `experiments/tools/jl`
# (one after another here): TraitWorld (product setting and the test bed `all`), the acceptance suite (both),
# the four demonstrators, the documentation's examples, TraitReport's and TraitMakie's REPL sessions. Logs to logs/<tag>/;
# a summary line each. A session passes only when every check prints ok and only the expected errors show.
#     bash run_all.sh <tag>
R=${TW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
J=$R/julia-1.13/julia; FI=$R/julia-1.13/usr/lib/julia/facts/sys.so
L=$R/experiments/checks/logs/$1; mkdir -p $L
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
run() {  # name, dir, mode, args...
  local name=$1 dir=$2 mode=$3; shift 3
  local F=""; if [ $mode = all ]; then F="-J $FI"; export JULIA_DEPOT_PATH=/tmp/claude-1000/depot-facts:$HOME/.julia:; else unset JULIA_DEPOT_PATH; fi
  (cd $dir && $R/experiments/tools/jl --name run_all-$mode timeout -s KILL 5400 $J $F --startup-file=no "$@" > $L/$name.log 2>&1); local rc=$?
  echo "$name rc=$rc  $(grep -E 'tests passed|of [0-9]+ checks pass|[0-9]+ pass, [0-9]+ fail|Test Failed|errored' $L/$name.log | tail -1)"
}
T='using Pkg; Pkg.test()'
run traitworld-product $R/TraitWorld plain --project=. -e "$T"
run traitworld-all     $R/TraitWorld all   --project=. -e "$T"
run acceptance-product $R/TraitWorld plain --project=. $R/experiments/facts/acceptance_compiler.jl
run acceptance-all     $R/TraitWorld all   --project=. $R/experiments/facts/acceptance_compiler.jl
for d in TraitTables TraitCSV TraitDifferentialEquations TraitMakie; do run $d $R/$d plain --project=. -e "$T"; done
for s in tutorial strict reference; do run doc-$s $R/TraitWorld plain --project=. $R/experiments/docs-examples/$s.jl; done
# TraitReport's REPL session (it takes the lock itself; about 7 s)
(unset JULIA_DEPOT_PATH; bash $R/TraitReport/scripts/session.sh > $L/traitreport-session.log 2>&1); echo "traitreport-session rc=$?  $(grep '^session:' $L/traitreport-session.log)"
# TraitMakie's REPL session (it takes the lock itself)
(unset JULIA_DEPOT_PATH; bash $R/TraitMakie/scripts/session.sh > $L/traitmakie-session.log 2>&1); echo "traitmakie-session rc=$?  $(grep '^session:' $L/traitmakie-session.log)"
echo done
