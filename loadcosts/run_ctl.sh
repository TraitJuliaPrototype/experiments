#!/bin/bash
# E-142: ctl_diag.jl in the control's environment (factscompiler/control/run.sh): the test bed
# `all` (facts system image, its own depot) or plain, TraitReport/env_loads, the round's CSV file.
#     MODE=all|plain bash run_ctl.sh <tag> [Pkg ...]   -> logs/ctl-<tag>.log, .trace, .inv, .new, .prof
R=/home/hellmann/Repos/julia-trait-bound
J=$R/julia-1.13/julia
FACTSIMG=$R/julia-1.13/usr/lib/julia/facts/sys.so
CSVF=$R/experiments/interfaces/App/data/sample.csv
L=$R/experiments/loadcosts/logs
export JULIA_LOAD_PATH="$R/TraitReport/env_loads:@stdlib" JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
if [ "${MODE:-all}" = all ]; then F="-J $FACTSIMG"; export JULIA_DEPOT_PATH=/tmp/claude-1000/depot-facts:$HOME/.julia:; else F=""; unset JULIA_DEPOT_PATH; fi
tag=$1; shift
LOADS="$@"; [ -z "$LOADS" ] && LOADS="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"
cd $R/experiments/loadcosts
flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 3600 $J $F --startup-file=no ctl_diag.jl $CSVF $L/ctl-$tag $LOADS \
  > $L/ctl-$tag.log 2> $L/ctl-$tag.trace
echo "exit $?"
