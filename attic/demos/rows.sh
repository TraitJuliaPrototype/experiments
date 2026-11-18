#!/bin/bash
# The demonstrators' rows (<demo>/scripts/rows.jl) on stock and patched, loads none/before/after.
# BUILDS= ORDERS= DEMOS= to restrict; JFLAGS="-J <image>" for a system image (experiments/sysimage).
# Environments: <demo>/scripts/env (TraitWorld and the demo by path) stacked on
# experiments/interfaces/env (CSV, DataFrames, CairoMakie). Precompile once per build and image.
# the demonstrators' rows (scripts/rows.jl) on stock and patched, loads none/before/after
cd /home/hellmann/Repos/julia-trait-bound
L=${JULIA_LOCK:-$TMPDIR/julia.lock}
export JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_PKG_OFFLINE=true
for build in ${BUILDS:-stock patched}; do
  if [ $build = stock ]; then J=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia; else J=julia-1.13/julia; fi
  for d in ${DEMOS:-TraitDifferentialEquations TraitMakie}; do
    for o in ${ORDERS:-none before after}; do
      echo "== $d $build $o"
      JULIA_LOAD_PATH="$d/scripts/env:experiments/interfaces/env:@stdlib" flock $L nice -n 10 timeout 1200 $J ${JFLAGS:-} --startup-file=no $d/scripts/rows.jl $o 2>&1 | grep -E "^row|^loads|^using|ERROR|rror:" | head -20
    done
  done
done
