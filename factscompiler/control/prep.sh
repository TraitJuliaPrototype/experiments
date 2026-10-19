#!/bin/bash
# Precompile TraitReport's env_loads under the facts system image (depot of its own), under a memory watchdog.
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
FACTSIMG=/home/hellmann/Repos/julia-trait-bound/julia-1.13/usr/lib/julia/facts/sys.so
export JULIA_DEPOT_PATH=$TMPDIR/depot-facts:$HOME/.julia: JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
setsid nice -n 10 $J -J $FACTSIMG --startup-file=no --project=/home/hellmann/Repos/julia-trait-bound/TraitReport/env_loads -e 'using Pkg; t = @elapsed Pkg.precompile(); println("precompile ", round(t; digits=1), " s")' & pid=$!
while kill -0 $pid 2>/dev/null; do
  avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  if [ "$avail" -lt 4096 ]; then echo "WATCHDOG: MemAvailable ${avail} MB, killing"; kill -TERM -$pid; sleep 5; kill -KILL -$pid 2>/dev/null; exit 99; fi
  sleep 10
done
wait $pid
