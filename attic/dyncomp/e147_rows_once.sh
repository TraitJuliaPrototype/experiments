#!/bin/bash
# E-147 (W-4, a short check, not a measurement): does every demonstrator row still run after the
# Compiled/Dynamic change, and is any row grossly slower? TraitDifferentialEquations' rows and
# TraitMakie's rows, once each, load order "none", product setting; compared with E-146's logs
# (TraitDifferentialEquations, TraitWorld 226db6a) and TraitMakie's README rows. One job at a time.
#     bash e147_rows_once.sh <tag>      -> logs/e147-<tag>.log
R=/home/hellmann/Repos/julia-trait-bound
J=$R/julia-1.13/julia
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
unset JULIA_DEPOT_PATH
out=$R/experiments/dyncomp/logs/e147-$1.log; : > $out
echo "-- TraitDifferentialEquations rows none, load $(cut -d' ' -f1 /proc/loadavg)" >> $out
(export JULIA_LOAD_PATH="$R/TraitDifferentialEquations/scripts/env:$R/TraitReport/env_loads:@stdlib"
 cd $R/TraitDifferentialEquations
 flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no --project=scripts/env -e 'using Pkg; Pkg.precompile()' > /dev/null 2>&1
 flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 900 $J --startup-file=no scripts/rows.jl none 2>&1 | grep -E "^(row|loads|using)|ERROR|rror:" >> $out)
echo "-- TraitMakie rows, load $(cut -d' ' -f1 /proc/loadavg)" >> $out
(cd $R/TraitMakie
 flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 900 $J --startup-file=no --project=. scripts/rows.jl none 2>&1 | grep -E "^(row|loads)|ERROR|rror:" >> $out)
echo done >> $out
