#!/bin/bash
# E-269 (X3): x3.jl at 0, 1, 10, 100 members on vanilla and the unified build, two runs each;
# then the quick BaseBenchmarks subset: vanilla without methods, unified without and with 100 members,
# two runs each. One process at a time, one thread, niced.
#     experiments/unification/x3/run.sh <session>
R=$(cd "$(dirname "$0")/../../.." && pwd); X=$R/experiments/unification/x3; S=$1
source $R/env.sh >/dev/null 2>&1
mkdir -p $X/logs
for run in 1 2; do
  for k in 0 1 10 100; do
    for t in vanilla unified; do
      X3_MEMBERS=$k JULIA_NUM_THREADS=1 nice -n 10 $R/julia-$t/julia --startup-file=no $X/x3.jl $S-r$run-$t-k$k > /dev/null 2>> $X/logs/$S-x3.err
    done
  done
done
for run in 1 2; do
  for cfg in vanilla:0 unified:0 unified:100; do
    t=${cfg%%:*}; k=${cfg##*:}
    X3_MEMBERS=$k JULIA_NUM_THREADS=1 nice -n 10 $R/julia-$t/julia --startup-file=no --pkgimages=no \
      --project=$R/experiments/factscompiler/step0/benv $X/bench_quick.jl $S-r$run-$t-k$k >> $X/logs/$S-quick.log 2>&1
  done
done
echo "E-269 $S done"
