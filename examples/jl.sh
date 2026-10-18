#!/bin/bash
# Run one Julia process under the shared lock, niced, with the switches every example run uses.
#   examples/jl.sh [julia args…] script.jl [args…]
# JULIA_TW_COMPILER_FACTS=0 while the parent validates parts (B)+(C); drop it afterwards.
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
export JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_TW_VIEWCACHE=0 JULIA_TW_COMPILER_FACTS=${JULIA_TW_COMPILER_FACTS-0}
exec flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 1800 "$J" --startup-file=no "$@"
