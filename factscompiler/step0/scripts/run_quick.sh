#!/bin/bash
# The quick subset in both modes, then the comparison: bash step0/scripts/run_quick.sh [label-suffix]
cd /home/hellmann/Repos/julia-trait-bound/experiments/factscompiler
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
FACTSIMG=/home/hellmann/Repos/julia-trait-bound/julia-1.13/usr/lib/julia/facts/sys.so
S=${1:-}
export JULIA_PKG_OFFLINE=true
for mode in plain all; do
  if [ $mode = all ]; then F="-J $FACTSIMG"; export JULIA_DEPOT_PATH=$TMPDIR/depot-facts:$HOME/.julia:; else F=""; unset JULIA_DEPOT_PATH; fi
  nice -n 10 timeout 1800 $J $F --startup-file=no --pkgimages=no --project=step0/benv step0/scripts/bench_quick.jl q-$mode$S 2>&1 | tail -2
done
unset JULIA_DEPOT_PATH
nice -n 10 $J --startup-file=no scripts/compare.jl q-plain$S q-all$S
