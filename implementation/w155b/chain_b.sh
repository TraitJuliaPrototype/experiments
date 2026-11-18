#!/bin/bash
# W-155b: the checks on next-s3 e483299622 (D-11, open issue 211, D-12, D-9), one after another.
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; cd "$H"
L=${1:-b}
rev() { git -C "$1" log -1 --format=%h; }
bash suites.sh julia-s3 $L tests > /dev/null 2>&1
echo "# precompile $(date -Is) | s3 $(rev $TW_ROOT/julia-s3)" > logs/$L-precompile.log
for e in env_forks env_facts env_demo env_session; do
  JULIA_NUM_PRECOMPILE_TASKS=4 nice -n 10 $JS --startup-file=no --project=$e -e 'using Pkg; Pkg.precompile()' >> logs/$L-precompile.log 2>&1
done
bash suites.sh julia-s3 $L digests > /dev/null 2>&1
nice -n 10 $JS --startup-file=no --project=env_lib diag/why_not_deep.jl TraitWorld > logs/$L-why-lib.log 2>&1
nice -n 10 $JS --startup-file=no --project=env_forks diag/why_not_deep.jl $CSVFILE CSV DataFrames Tables TraitWorld > logs/$L-why-forks.log 2>&1
{ echo "# E-457 loads | s3 $(rev $TW_ROOT/julia-s3) | TraitWorld-s3 $(rev $TW_ROOT/TraitWorld-s3)+wt | load $(cut -d' ' -f1-3 /proc/loadavg) | $(date -Is)"
  W155B_COUNT=1 nice -n 10 $JS --startup-file=no --project=env_forks loads.jl $CSVFILE $LOADS 2>&1 | tail -1
  for r in 1 2; do
    JULIA_TW_PIRATES=0 nice -n 10 $JS --startup-file=no --project=env_forks loads.jl $CSVFILE $LOADS 2>&1 | tail -1
    nice -n 10 $JS --startup-file=no --project=env_forks loads.jl $CSVFILE $LOADS 2>&1 | tail -1
  done; echo "load after $(cut -d' ' -f1-3 /proc/loadavg)"; } > logs/$L-loads.log
P5=$TW_ROOT/experiments/implementation/w152/p5/sites.jl
{ echo "# E-458 (a) sites | s3 $(rev $TW_ROOT/julia-s3) | load $(cut -d' ' -f1-3 /proc/loadavg) | $(date -Is)"
  SITES_ROOTS=CSV,DataFrames,Tables nice -n 10 $JS --startup-file=no --project=env_forks $P5 CSV DataFrames 2>&1
  SITES_ROOTS=TraitCSV,TraitTables,TraitMakie nice -n 10 $JS --startup-file=no --project=env_demo $P5 TraitCSV TraitTables TraitMakie 2>&1
  SITES_ROOTS=TraitDifferentialEquations,ODECore,TraitRodas,TraitNonlinearSolve,TraitLinSolvers,TraitNLSolvers,TraitImplicit,TraitIndexing,TraitArrayTools nice -n 10 $JS --startup-file=no --project=env_demo $P5 TraitDifferentialEquations 2>&1
} > logs/$L-sites.log
bash owner_only/run.sh e458 > /dev/null 2>&1
echo "chain $L done $(date -Is)" >> logs/$L-summary.log
