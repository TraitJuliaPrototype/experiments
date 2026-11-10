#!/bin/bash
# E-355: bash run.sh <label> [runs=2] -- each configuration and order: a warm-up, then <runs> fresh processes, one at a time.
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
label=$1; runs=${2:-2}; J=$R/julia-unified/julia
CSV=$R/experiments/interfaces/App/data/sample.csv
LOADS="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
LOG=$H/logs/$label.log
rev() { git -C "$R/$1" log -1 --format=%h; }
echo "# E-355 $label $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | unified $(rev julia-unified) (binary $($J --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')) TraitWorld-unified $(rev TraitWorld-unified) forks-unified $(rev forks-unified) experiments $(rev experiments)" > "$LOG"
for env in ${ENVS:-env_up env_facts env_forks}; do
  for order in ${ORDERS:-A B}; do
    for i in w $(seq "$runs"); do
      echo "== $env $order run $i | load $(cut -d' ' -f1 /proc/loadavg)" >> "$LOG"
      nice -n 10 timeout 1800 "$J" --startup-file=no --project="$H/$env" "$H/lost.jl" $order "$CSV" $LOADS 2>&1 | grep -v "^ *$" | cut -c1-1500 | head -40 >> "$LOG"
    done
  done
done
echo "# done $(date -Is)" >> "$LOG"
