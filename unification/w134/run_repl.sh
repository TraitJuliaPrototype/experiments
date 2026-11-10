#!/bin/bash
# E-359: bash run_repl.sh <label> [runs=2] -- each session: a warm-up, then <runs> fresh processes, one at a time.
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
label=$1; runs=${2:-2}; J=$R/julia-unified/julia
CSV=$R/TraitReport-unified/data/sensors.csv
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
LOG=$H/logs/$label.log; OUT=$(mktemp -d)
rev() { git -C "$R/$1" log -1 --format=%h; }
echo "# E-359 $label $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | unified $(rev julia-unified) (binary $($J --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')) TraitWorld-unified $(rev TraitWorld-unified) TDE $(rev TraitDifferentialEquations-unified) TraitMakie $(rev TraitMakie-unified) TraitCSV $(rev TraitCSV-unified) TraitTables $(rev TraitTables-unified) TraitReport $(rev TraitReport-unified) experiments $(rev experiments)" > "$LOG"
for kind in ${KINDS:-T Tp D}; do
  for i in w $(seq "$runs"); do
    echo "== $kind run $i | load $(cut -d' ' -f1 /proc/loadavg)" >> "$LOG"
    nice -n 10 timeout 900 "$J" --startup-file=no --project="$H/env_demo" "$H/repl.jl" $kind "$CSV" "$OUT" 2>&1 | grep -v "^ *$" | cut -c1-420 | head -80 >> "$LOG"
  done
done
rm -rf "$OUT"; echo "# done $(date -Is)" >> "$LOG"
