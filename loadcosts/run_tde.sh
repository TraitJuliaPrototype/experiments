#!/bin/bash
# E-141: tde_diag.jl in the round's environment (measure_all.sh's "tde" part): product setting,
# default depot, the demonstrator's env stacked on TraitReport/env_loads. One job, niced, locked.
#     bash run_tde.sh <mode> <tag> [Pkg ...]     -> logs/tde-<tag>.log, .trace, .inv, .row*.cis
R=/home/hellmann/Repos/julia-trait-bound
J=$R/julia-1.13/julia
L=$R/experiments/loadcosts/logs
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
unset JULIA_DEPOT_PATH
export JULIA_LOAD_PATH="$R/TraitDifferentialEquations/scripts/env:$R/TraitReport/env_loads:@stdlib"
mode=$1; tag=$2; shift 2
cd $R/TraitDifferentialEquations
PROFDELAY=${PROFDELAY:-0.0005} PROFROW=${PROFROW:-0} flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 1800 $J --startup-file=no \
  $R/experiments/loadcosts/tde_diag.jl $mode $L/tde-$tag "$@" > $L/tde-$tag.log 2> $L/tde-$tag.trace
echo "exit $?"
