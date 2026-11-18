#!/bin/bash
# E-431: the census in the round's environment, on julia-s3 (W-155b). Precompiles the three environments
# first (into this agent's depot), then runs census.jl in each. Logs: ../logs/e431-*.log
H=$(cd "$(dirname "$0")/.." && pwd); source "$H/env.sh"; cd "$H"
L=${1:-e431}
echo "# precompile $(date -Is) | s3 $(git -C $TW_ROOT/julia-s3 rev-parse --short=10 HEAD)" > logs/$L-precompile.log
for e in env_forks env_facts env_demo; do
  JULIA_NUM_PRECOMPILE_TASKS=4 nice -n 10 $JS --startup-file=no --project=$e -e 'using Pkg; Pkg.precompile()' >> logs/$L-precompile.log 2>&1
done
hdr() { echo "== $1 | load $(cut -d' ' -f1-3 /proc/loadavg) | s3 $(git -C $TW_ROOT/julia-s3 rev-parse --short=10 HEAD) | TraitWorld-s3 $(git -C $TW_ROOT/TraitWorld-s3 log -1 --format=%h) | forks $(git -C $TW_ROOT/forks log -1 --format=%h) | ODE $(git -C $TW_ROOT/TraitDifferentialEquations-s3 log -1 --format=%h) | TraitMakie $(git -C $TW_ROOT/TraitMakie log -1 --format=%h) | $(date -Is)"; }
{ hdr env_forks; nice -n 10 $JS --startup-file=no --project=env_forks owner_only/census.jl $CSVFILE CSV DataFrames Tables TraitWorld $LOADS 2>&1
  hdr env_facts; nice -n 10 $JS --startup-file=no --project=env_facts owner_only/census.jl $CSVFILE CSV DataFrames Tables $LOADS 2>&1
  hdr env_demo;  nice -n 10 $JS --startup-file=no --project=env_demo owner_only/census.jl TraitWorld TraitCSV TraitTables TraitMakie TraitDifferentialEquations $LOADS 2>&1
} > logs/$L-census.log
echo "done $(date -Is)" >> logs/$L-census.log
