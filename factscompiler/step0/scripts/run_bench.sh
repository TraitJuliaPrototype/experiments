#!/bin/bash
# Both modes, one process each, niced; results in ../results/<label>.
cd /home/hellmann/Repos/julia-trait-bound/experiments/factscompiler
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
FACTSIMG=/home/hellmann/Repos/julia-trait-bound/julia-1.13/usr/lib/julia/facts/sys.so
BGROUPS=${BGROUPS:-"array broadcast collection dates find io micro misc problem scalar shootout simd sort sparse string tuple union"}
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
for mode in ${MODES:-plain all}; do
  if [ $mode = all ]; then F="-J $FACTSIMG"; export JULIA_DEPOT_PATH=$TMPDIR/depot-facts:$HOME/.julia:; else F=""; unset JULIA_DEPOT_PATH; fi
  echo "== $mode $(date +%T)"
  nice -n 10 timeout 7200 $J $F --startup-file=no --pkgimages=no --project=step0/benv step0/scripts/bench.jl s0-$mode ${SECS:-0.2} $BGROUPS 2>&1
done
echo "== done $(date +%T)"
