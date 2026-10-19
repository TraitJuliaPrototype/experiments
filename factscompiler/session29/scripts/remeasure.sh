#!/bin/bash
# Rows changed by the machinery fix, and TDE's run time with its load path.
R=/home/hellmann/Repos/julia-trait-bound; J=$R/julia-1.13/julia; M=/tmp/claude-1000/demos/m
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
BIG=$R/TraitReport/env_loads
L=/tmp/claude-1000/julia-review.lock
pc() { flock $L nice -n 10 timeout 5400 $J --startup-file=no --project=$1 -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1; }
for e in $R/TraitDifferentialEquations/scripts/env $R/TraitMakie/scripts/env $R/TraitReport/env_t $R/TraitReport/env_pt $BIG $R/forks/env_forks; do pc $e; done
echo "### tde"; cd $R/TraitDifferentialEquations
for l in none before after; do echo "-- rows $l"
  JULIA_LOAD_PATH="$R/TraitDifferentialEquations/scripts/env:$BIG:@stdlib" flock $L nice -n 10 timeout 1800 $J --startup-file=no scripts/rows.jl $l 2>&1 | grep -E "^(row|loads|using)|ERROR|rror:"; done | tee $M/tde-rows2.log
echo "-- runtime"; JULIA_LOAD_PATH="scripts/env:$R/experiments/solvers/env:@stdlib" flock $L nice -n 10 timeout 1800 $J --startup-file=no scripts/runtime.jl 2>&1 | tail -14 | tee $M/tde-runtime.log
echo "### makie"; cd $R/TraitMakie
for l in none before after; do echo "-- rows $l"
  JULIA_LOAD_PATH="$R/TraitMakie/scripts/env:$BIG:@stdlib" flock $L nice -n 10 timeout 1800 $J --startup-file=no scripts/rows.jl $l 2>&1 | grep -E "^(row|loads)|ERROR|rror:"; done | tee $M/makie-rows2.log
echo "### report loads"; cd $R/TraitReport; J=$J L=$L bash scripts/loads.sh 2>&1 | tee $M/report-loads2.log
echo "### forks imports"; cd $R/forks
for i in 1 2; do flock $L nice -n 10 timeout 1800 $J --startup-file=no --project=env_forks -e '@time "using CSV" using CSV; @time "using DataFrames" using DataFrames' 2>&1 | tail -3; done
echo "### done"
