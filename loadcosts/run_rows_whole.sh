#!/bin/bash
# E-146: TraitDifferentialEquations' rows timed whole (rows.jl's `@first`), three load orders, two
# runs each, product setting, the round's environment. One job at a time, niced, locked.
#     bash run_rows_whole.sh <tag>      -> logs/rowswhole-<tag>.log
R=/home/hellmann/Repos/julia-trait-bound
J=$R/julia-1.13/julia
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
unset JULIA_DEPOT_PATH
export JULIA_LOAD_PATH="$R/TraitDifferentialEquations/scripts/env:$R/TraitReport/env_loads:@stdlib"
cd $R/TraitDifferentialEquations
out=$R/experiments/loadcosts/logs/rowswhole-$1.log; : > $out
flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no --project=scripts/env -e 'using Pkg; Pkg.precompile()' >> $out 2>&1
for l in none before after; do for i in 1 2; do
  echo "-- rows $l run $i load $(cut -d' ' -f1 /proc/loadavg)" >> $out
  flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 1800 $J --startup-file=no scripts/rows.jl $l 2>&1 | grep -E "^(row|loads|using)|ERROR|rror:" >> $out
done; done
echo done >> $out
