#!/bin/bash
# usage: ./run.sh product|all <args to julia...>   (from this directory). One job at a time, through the shared lock, niced.
# Depots of their own first, so that nothing is precompiled into the main checkouts' caches.
set -u
mode=$1; shift
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
export JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_PKG_OFFLINE=true
if [ "$mode" = all ]; then
  export JULIA_DEPOT_PATH=/tmp/claude-1000/depot-fb-facts:/tmp/claude-1000/depot-facts:$HOME/.julia:
  exec flock /tmp/claude-1000/julia-review.lock nice -n 19 $J -J /home/hellmann/Repos/julia-trait-bound/julia-1.13/usr/lib/julia/facts/sys.so --startup-file=no "$@"
else
  export JULIA_DEPOT_PATH=/tmp/claude-1000/depot-fb:$HOME/.julia:
  exec flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no "$@"
fi
