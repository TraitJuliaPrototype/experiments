#!/bin/bash
# E-156: run the probes serially, each in a fresh session, through the shared lock, niced.
# usage: ./run_probes.sh [P1a P1b …]   (from any directory; no arguments: all probes)
# Product setting (no -J facts sys.so), strict mode off. Logs: logs/<probe>.log.
set -u
cd "$(dirname "$0")"
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
export JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_PKG_OFFLINE=true JULIA_TW_STRICT=0
# a depot of its own first, so that nothing is precompiled into the main checkouts' caches
export JULIA_DEPOT_PATH=/tmp/claude-1000/depot-w34:$HOME/.julia:
ALL="P1a P1a_prime P1b P1c P5 P7 P8 P9 P10 P11 P12 P14 P13 P15 X1_base_name"
probes=${*:-$ALL}
for p in $probes; do
  echo "--- $p  (load $(cut -d' ' -f1-3 /proc/loadavg))"
  timeout 600 flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no --project=. probes/$p.jl > logs/$p.log 2>&1
  echo "exit $?" >> logs/$p.log
  grep -h '^RESULT' logs/$p.log || echo "RESULT $p ERROR (no result line; see logs/$p.log)"
done
