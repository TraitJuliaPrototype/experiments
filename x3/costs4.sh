#!/bin/bash
# E-226 (X3, slice 4): costs in fresh processes, 2 runs each after one untimed warm-up per environment (the precompile).
#     bash experiments/x3/costs4.sh > experiments/x3/logs/costs-slice4.log
R=/home/hellmann/Repos/julia-trait-bound; X=$R/experiments/x3; J=$R/julia-1.13/julia
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
O=$(mktemp -d)
run() { flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no --project=$X/$1 $X/costs.jl $2 $O 2>&1 | grep X3C; }
for e in env env-nowl; do run $e stephist > /dev/null; done
for i in 1 2; do
  for k in core old stephist; do run env $k; done
  for k in old stephist; do run env-nowl $k; done
done
