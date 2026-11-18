#!/bin/bash
# W-155b: the checks on next-s3 1dc4c7b3ae (D-13, open issue 189's fix), one after another, after the gate
# `test/delete.jl` alone: Julia's four tests, the environments' images made again, the forks' digests, the
# deep class's reasons (open issue 211's tool, fixed), E-457's loads again with more runs.
#     bash chain_c.sh [label]
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; cd "$H"
L=${1:-c}
rev() { git -C "$1" log -1 --format=%h; }
bash suites.sh julia-s3 $L library tests > /dev/null 2>&1
echo "# precompile $(date -Is) | s3 $(rev $TW_ROOT/julia-s3)" > logs/$L-precompile.log
for e in env_forks env_facts env_demo env_session; do
  JULIA_NUM_PRECOMPILE_TASKS=4 nice -n 10 $JS --startup-file=no --project=$e -e 'using Pkg; Pkg.precompile()' >> logs/$L-precompile.log 2>&1
done
bash suites.sh julia-s3 $L digests > /dev/null 2>&1
nice -n 10 $JS --startup-file=no --project=env_lib diag/why_not_deep.jl TraitWorld > logs/$L-why-lib.log 2>&1
nice -n 10 $JS --startup-file=no --project=env_forks diag/why_not_deep.jl $CSVFILE CSV DataFrames Tables TraitWorld > logs/$L-why-forks.log 2>&1
{ echo "# E-457 loads | s3 $(rev $TW_ROOT/julia-s3) | TraitWorld-s3 $(rev $TW_ROOT/TraitWorld-s3)+wt | load $(cut -d' ' -f1-3 /proc/loadavg) | $(date -Is)"
  W155B_COUNT=1 nice -n 10 $JS --startup-file=no --project=env_forks loads.jl $CSVFILE $LOADS 2>&1 | tail -1
  for r in 1 2 3 4; do
    JULIA_TW_PIRATES=0 nice -n 10 $JS --startup-file=no --project=env_forks loads.jl $CSVFILE $LOADS 2>&1 | tail -1
    nice -n 10 $JS --startup-file=no --project=env_forks loads.jl $CSVFILE $LOADS 2>&1 | tail -1
  done; echo "load after $(cut -d' ' -f1-3 /proc/loadavg)"; } > logs/$L-loads.log
echo "chain $L done $(date -Is)" >> logs/$L-summary.log
