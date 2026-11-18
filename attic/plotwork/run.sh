#!/bin/bash
# The plotting workload, plain against the test bed `all`, fresh processes, one at a time.
# Usage: ORDERS="interleaved together" SIZES="10k 200k" REPS=8 RUNS=3 bash run.sh > logs/run.log
cd /home/hellmann/Repos/julia-trait-bound/experiments/plotwork
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
FACTSIMG=/home/hellmann/Repos/julia-trait-bound/julia-1.13/usr/lib/julia/facts/sys.so
D=$TMPDIR/plotwork; mkdir -p $D/out
LOADS="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays"
export JULIA_LOAD_PATH="/home/hellmann/Repos/julia-trait-bound/TraitReport/env_loads:@stdlib" JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
for order in ${ORDERS:-interleaved together}; do
for size in ${SIZES:-10k}; do
  for run in $(seq ${RUNS:-3}); do
    for mode in ${MODES:-plain all}; do
      if [ $mode = all ]; then F="-J $FACTSIMG"; export JULIA_DEPOT_PATH=$TMPDIR/depot-facts:$HOME/.julia:; else F=""; unset JULIA_DEPOT_PATH; fi
      echo "== $mode $order $size run $run $(date +%T) load $(cut -d' ' -f1 /proc/loadavg)"
      s=$(date +%s.%N)
      PLOTWORK_ORDER=$order nice -n 10 timeout 1800 $J $F --startup-file=no plotwork.jl $D/data$size.csv ${REPS:-5} $D/out $LOADS 2>&1 | grep -E "^(ROW|TOTAL)|ERROR|rror" | head -80
      echo "WALL $mode $order $size $(echo "$(date +%s.%N) - $s" | bc)"
    done
  done
done
done
