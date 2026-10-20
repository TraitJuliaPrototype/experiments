#!/bin/bash
# E-141: TraitDifferentialEquations/scripts/rows.jl unchanged, in the round's environment, with
# Julia's compile trace (--trace-compile=stderr --trace-compile-timing) interleaved with its rows.
#     bash run_rows_traced.sh <mode> <run>   -> logs/rows-<mode>-<run>.log
R=/home/hellmann/Repos/julia-trait-bound
J=$R/julia-1.13/julia
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
unset JULIA_DEPOT_PATH
export JULIA_LOAD_PATH="$R/TraitDifferentialEquations/scripts/env:$R/TraitReport/env_loads:@stdlib"
cd $R/TraitDifferentialEquations
T=""; [ "${TRACE:-1}" = 1 ] && T="--trace-compile=stderr --trace-compile-timing"
flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 1800 $J --startup-file=no $T scripts/rows.jl $1 \
  2>&1 | cat > $R/experiments/loadcosts/logs/rows-$1-$2${TAG}.log
