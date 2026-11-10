#!/bin/bash
# E-356: bash plain.sh <label> [runs=3] -- V (vanilla), U (unified), L (the library first), then U with the library late; interleaved.
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
label=$1; runs=${2:-3}; CSV=$R/experiments/interfaces/App/data/sample.csv
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
LOG=$H/logs/$label.log
rev() { git -C "$R/$1" log -1 --format=%h; }
echo "# E-356 $label $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | vanilla $(rev julia-vanilla) unified $(rev julia-unified) TraitWorld-unified $(rev TraitWorld-unified) experiments $(rev experiments)" > "$LOG"
one() { echo "== $1 run $4 | load $(cut -d' ' -f1 /proc/loadavg)" >> "$LOG"
  nice -n 10 timeout 1800 "$R/$2/julia" --startup-file=no --project="$H/$3" "$H/plain.jl" "$CSV" $5 2>&1 | grep -v "^ *$" | cut -c1-400 | head -30 >> "$LOG"; }
for i in w $(seq "$runs"); do
  one V julia-vanilla env_up $i none
  one U julia-unified env_up $i none
  one L julia-unified env_lib $i first
  one U-late julia-unified env_lib $i late
done
echo "# done $(date -Is)" >> "$LOG"
