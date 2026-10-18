#!/bin/bash
# The control: plain table code and upstream CSV+DataFrames under loads, plain and `all`.
cd /home/hellmann/Repos/julia-trait-bound/experiments/factscompiler/control
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
FACTSIMG=/home/hellmann/Repos/julia-trait-bound/julia-1.13/usr/lib/julia/facts/sys.so
CSV=/home/hellmann/Repos/julia-trait-bound/experiments/interfaces/App/data/sample.csv
LOADS="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"
export JULIA_LOAD_PATH="/home/hellmann/Repos/julia-trait-bound/TraitReport/env_loads:@stdlib" JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
for mode in ${MODES:-plain all}; do
  if [ $mode = all ]; then F="-J $FACTSIMG"; export JULIA_DEPOT_PATH=$TMPDIR/depot-facts:; else F=""; unset JULIA_DEPOT_PATH; fi
  for w in ${WORKS:-plaintables upstream}; do
    echo "== $mode $w"
    nice -n 10 timeout 3600 $J $F --startup-file=no lost.jl $w $CSV $LOADS 2>&1 | grep -E "^(mode|work|valid|lost)|ERROR|rror:" | head -8
  done
done
