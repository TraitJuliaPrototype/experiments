#!/bin/bash
# W-161, E-499: E-381's plain-code session (W-134's plain.jl) on the same day: vanilla (V), the baseline
# julia-unified with the tag's library (B-*), the head julia-next with D-4 and TraitWorld (H-*); the library
# loaded first and late. A warm-up and <runs> runs, interleaved.
#     bash plain.sh <label> [runs=3]
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); source "$H/../env.sh"
label=$1; runs=${2:-3}; W=$TW_ROOT/experiments/implementation/w134
LOG=$H/logs/$label.log
rev() { git -C "$TW_ROOT/$1" log -1 --format=%h; }
echo "# E-499 $label $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | vanilla $(rev julia-vanilla) unified $(rev julia-unified) TraitWorld-base $(rev TraitWorld-base) | next $(rev julia-next) TraitWorld $(rev TraitWorld)" > "$LOG"
one() { echo "== $1 run $4 | load $(cut -d' ' -f1 /proc/loadavg)" >> "$LOG"
  nice -n 10 timeout 1800 "$TW_ROOT/$2/julia" --startup-file=no --project="$3" "$W/plain.jl" "$CSVFILE" $5 2>&1 | grep -v "^ *$" | cut -c1-300 | head -12 >> "$LOG"; }
for i in w $(seq "$runs"); do
  one V julia-vanilla $W/env_up $i none
  one B-first julia-unified $H/env_base_lib $i first
  one H-first julia-next $H/../env_lib $i first
  one B-late julia-unified $H/env_base_lib $i late
  one H-late julia-next $H/../env_lib $i late
done
echo "# done $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg)" >> "$LOG"
