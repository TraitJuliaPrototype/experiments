#!/bin/bash
# The after-loads diagnosis in both modes (control/run.sh's environment); the compile trace to logs/.
cd /home/hellmann/Repos/julia-trait-bound/experiments/factscompiler/step0
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
FACTSIMG=/home/hellmann/Repos/julia-trait-bound/julia-1.13/usr/lib/julia/facts/sys.so
CSV=/home/hellmann/Repos/julia-trait-bound/experiments/interfaces/App/data/sample.csv
LOADS=${LOADS:-"OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"}
export JULIA_LOAD_PATH="/home/hellmann/Repos/julia-trait-bound/TraitReport/env_loads:@stdlib" JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
for mode in ${MODES:-all plain}; do
  if [ $mode = all ]; then F="-J $FACTSIMG"; export JULIA_DEPOT_PATH=$TMPDIR/depot-facts:$HOME/.julia:; else F=""; unset JULIA_DEPOT_PATH; fi
  echo "== $mode $(date +%T)"
  nice -n 10 timeout 3600 $J $F --startup-file=no scripts/afterloads.jl $CSV $LOADS 2> logs/afterloads-$mode${TAG}.trace
  grep -E "ERROR|rror:" logs/afterloads-$mode${TAG}.trace | head -5
done
