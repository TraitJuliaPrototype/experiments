#!/bin/bash
# E-357: bash run_demo.sh <label> [runs=2] -- each session and order: a warm-up, then <runs> fresh processes, one at a time.
# KINDS (default "D T Tp"): Dp, the plain ODE twin, does not load on the unified build (open issue 160).
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
label=$1; runs=${2:-2}; J=$R/julia-unified/julia
CSV=$R/TraitReport-unified/data/sensors.csv
LOADS="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
LOG=$H/logs/$label.log; OUT=$(mktemp -d)
rev() { git -C "$R/$1" log -1 --format=%h; }
echo "# E-357 $label $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | unified $(rev julia-unified) (binary $($J --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')) TraitWorld-unified $(rev TraitWorld-unified) TDE $(rev TraitDifferentialEquations-unified) TraitMakie $(rev TraitMakie-unified) TraitCSV $(rev TraitCSV-unified) TraitTables $(rev TraitTables-unified) TraitReport $(rev TraitReport-unified) experiments $(rev experiments)" > "$LOG"
for kind in ${KINDS:-D T Tp}; do
  for order in ${ORDERS:-A B}; do
    for i in w $(seq "$runs"); do
      echo "== $kind $order run $i | load $(cut -d' ' -f1 /proc/loadavg)" >> "$LOG"
      nice -n 10 timeout 1800 "$J" --startup-file=no --project="$H/env_demo" "$H/lost_demo.jl" $kind $order "$CSV" "$OUT" $LOADS 2>&1 | grep -v "^ *$" | cut -c1-700 | head -40 >> "$LOG"
    done
  done
done
rm -rf "$OUT"; echo "# done $(date -Is)" >> "$LOG"
