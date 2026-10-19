#!/bin/bash
# The short round (2026-10-19 evening): call benchmarks, the quick subset, and a small set of the
# demonstrators' rows (the control, TraitMakie and TDE clean and after loads, TraitReport against
# Python). The full BaseBenchmarks and the full demonstrator harness run overnight (round/run.sh).
R=/home/hellmann/Repos/julia-trait-bound; F=$R/experiments/factscompiler; L=$F/round/logs
J=$R/julia-1.13/julia; FI=$R/julia-1.13/usr/lib/julia/facts/sys.so; FD=$TMPDIR/depot-facts:$HOME/.julia:
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=8
step() { echo "### $1 $(date +%T)"; }
pc() { $J --startup-file=no --project=$1 -e 'using Pkg; t = @elapsed Pkg.precompile(); println("precompile '"$1"' ", round(t; digits=1), " s")' 2>&1 | tail -1; }
cd $F
step calls
$J --startup-file=no --project=benv step1/callbench.jl > $L/callbench.log 2>&1; tail -5 $L/callbench.log
for m in plain all; do
  if [ $m = all ]; then A="-J $FI"; export JULIA_DEPOT_PATH=$FD; else A=""; unset JULIA_DEPOT_PATH; fi
  $J $A --startup-file=no --project=benv step3/untyped.jl > $L/untyped-$m.log 2>&1; echo "untyped $m"; tail -5 $L/untyped-$m.log
  $J $A --startup-file=no --project=step0/benv ic/sites.jl > $L/sites-$m.log 2>&1; tail -4 $L/sites-$m.log
done
unset JULIA_DEPOT_PATH
step quick
bash step0/scripts/run_quick.sh -final > $L/quick.log 2>&1; grep -E "^ALL|geomean" $L/quick.log | tail -18
step control
bash control/prep.sh 2>&1 | tail -1; pc $R/TraitReport/env_loads
bash control/run.sh > $L/control.log 2>&1; cat $L/control.log
BIG=$R/TraitReport/env_loads
step makie
pc $R/TraitMakie/scripts/env; cd $R/TraitMakie
for l in none after; do echo "-- rows $l"; JULIA_LOAD_PATH="$R/TraitMakie/scripts/env:$BIG:@stdlib" timeout 1800 $J --startup-file=no scripts/rows.jl $l 2>&1 | grep -E "^(row|loads)|ERROR|rror:"; done | tee $L/makie-rows.log
step tde
pc $R/TraitDifferentialEquations/scripts/env; cd $R/TraitDifferentialEquations
for l in none after; do echo "-- rows $l"; JULIA_LOAD_PATH="$R/TraitDifferentialEquations/scripts/env:$BIG:@stdlib" timeout 1800 $J --startup-file=no scripts/rows.jl $l 2>&1 | grep -E "^(row|loads|using)|ERROR|rror:"; done | tee $L/tde-rows.log
step report
pc $R/TraitReport/env_t; pc $R/TraitReport/env_pt; cd $R/TraitReport
JULIAS=$J JULIA_LOCK=/dev/null bash scripts/measure.sh 1 "t pt" 2>&1 | tee $L/report-measure.log | tail -12
step done
