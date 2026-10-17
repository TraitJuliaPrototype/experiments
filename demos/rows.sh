#!/bin/bash
# The demonstrators' rows (<demo>/scripts/rows.jl) on stock and patched, loads none/before/after.
# BUILDS= ORDERS= DEMOS= to restrict. Environments: $TMPDIR/env_main_<demo> (TraitWorld and the demo by path)
# stacked on experiments/interfaces/env (CSV, DataFrames, CairoMakie). Precompile once per build.
# the demonstrators' rows (scripts/rows.jl) on stock and patched, loads none/before/after
cd /home/hellmann/Repos/julia-trait-bound
L=/tmp/claude-1000/-home-hellmann-Repos-julia-trait-bound/6c8f1719-6fc1-42fb-a8dc-c45452eef443/scratchpad/julia.lock
export JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_PKG_OFFLINE=true
for build in ${BUILDS:-stock patched}; do
  if [ $build = stock ]; then J=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia; else J=julia-1.13/julia; fi
  for d in ${DEMOS:-TraitDifferentialEquations TraitMakie}; do
    for o in ${ORDERS:-none before after}; do
      echo "== $d $build $o"
      JULIA_LOAD_PATH="$TMPDIR/env_main_$d:experiments/interfaces/env:@stdlib" flock $L nice -n 10 timeout 1200 $J --startup-file=no $d/scripts/rows.jl $o 2>&1 | grep -E "^row|^loads|^using|ERROR|rror:" | head -20
    done
  done
done
