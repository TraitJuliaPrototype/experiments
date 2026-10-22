#!/bin/bash
# E-158: one Julia job, the machine's rules: the shared lock, two cores, idle I/O, nice 19, one thread.
# usage: ./jl.sh <julia args...>
export JULIA_NUM_PRECOMPILE_TASKS=1 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_TW_STRICT=0
export JULIA_DEPOT_PATH=/tmp/claude-1000/depot-w34:$HOME/.julia:
exec flock /tmp/claude-1000/julia-review.lock taskset -c 0-1 ionice -c3 nice -n 19 \
  /home/hellmann/Repos/julia-trait-bound/julia-1.13/julia --startup-file=no "$@"
