#!/bin/bash
# The demonstrators' "to measure after (D)" rows, one job at a time, niced; logs in /tmp/claude-1000/demos/m/.
R=/home/hellmann/Repos/julia-trait-bound
J=$R/julia-1.13/julia
M=/tmp/claude-1000/demos/m
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
pc() { nice -n 10 timeout 5400 $J --startup-file=no --project=$1 -e 'using Pkg; t = @elapsed Pkg.precompile(); println("precompile '"$1"' ", round(t; digits=1), " s")' 2>&1 | tail -2; }
step() { echo "### $1 $(date +%T)"; }
if [[ " ${PARTS:-control tde makie report forks} " == *" control "* ]]; then
  step control; bash $R/experiments/factscompiler/control/prep.sh 2>&1 | tail -2
  pc $R/TraitReport/env_loads
  bash $R/experiments/factscompiler/control/run.sh > $M/control.log 2>&1; cat $M/control.log
fi
BIG=$R/TraitReport/env_loads
if [[ " ${PARTS:-control tde makie report forks} " == *" tde "* ]]; then
  step tde; pc $R/TraitDifferentialEquations/scripts/env
  cd $R/TraitDifferentialEquations
  for l in none before after; do for i in 1 2; do echo "-- rows $l run $i"
    JULIA_LOAD_PATH="$R/TraitDifferentialEquations/scripts/env:$BIG:@stdlib" nice -n 10 timeout 1800 $J --startup-file=no scripts/rows.jl $l 2>&1 | grep -E "^(row|loads|using)|ERROR|rror:"; done; done | tee $M/tde-rows.log
  echo "-- runtime"; nice -n 10 timeout 1800 $J --startup-file=no --project=scripts/env scripts/runtime.jl 2>&1 | tail -12 | tee $M/tde-runtime.log
fi
if [[ " ${PARTS:-control tde makie report forks} " == *" makie "* ]]; then
  step makie; pc $R/TraitMakie/scripts/env
  cd $R/TraitMakie
  for l in none before after; do for i in 1 2; do echo "-- rows $l run $i"
    JULIA_LOAD_PATH="$R/TraitMakie/scripts/env:$BIG:@stdlib" nice -n 10 timeout 1800 $J --startup-file=no scripts/rows.jl $l 2>&1 | grep -E "^(row|loads)|ERROR|rror:"; done; done | tee $M/makie-rows.log
fi
if [[ " ${PARTS:-control tde makie report forks} " == *" report "* ]]; then
  step report; pc $R/TraitReport/env_t; pc $R/TraitReport/env_pt
  cd $R/TraitReport
  JULIAS=$J JULIA_LOCK=/dev/null bash scripts/measure.sh 3 "t pt" 2>&1 | tee $M/report-measure.log
  J=$J L=/dev/null bash scripts/loads.sh 2>&1 | tee $M/report-loads.log
fi
if [[ " ${PARTS:-control tde makie report forks} " == *" forks "* ]]; then
  step forks; pc $R/forks/env_forks; pc $R/forks/env_upstream
  cd $R/forks
  JULIA_LOCK=/dev/null bash scripts/measure_session.sh 3 "fk-patched up-patched" > $M/forks-session.log 2>&1; tail -5 $M/forks-session.log
  python3 scripts/summarize.py < $M/forks-session.log 2>&1 | tee $M/forks-summary.log
fi
step done
