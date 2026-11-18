#!/bin/bash
# W-156, third part (E-506): plain code's control. E-499's session of plain Julia (W-134's plain.jl: upstream CSV
# and DataFrames, no library), on vanilla v1.13.2 (V), `next` (N) and the w156 tree (W); and on W the library
# loaded first and late (its late load: what it ends of plain code). A warm-up and <runs> runs, interleaved; one
# thread, niced. The caches of vanilla and `next` come from W-161's depot, stacked below this part's.
#     bash plain-c.sh <label> [runs=3]          -> logs/c-<label>.log
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); source "$H/env-c.sh"
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w156c:$TW_ROOT/.julia-depot/agent-depots/w161:$TW_ROOT/.julia-depot:
label=$1; runs=${2:-3}; W=$TW_ROOT/experiments/implementation/w134; CSVFILE=$TW_ROOT/experiments/interfaces/App/data/sample.csv
LOG=$H/logs/c-$label.log
rev() { git -C "$TW_ROOT/$1" log -1 --format=%h; }
echo "# E-506 plain $label $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | vanilla $(rev julia-vanilla) next $(rev julia-next) w156 $(rev wt/w156-julia) TraitWorld $(rev TraitWorld)" > "$LOG"
one() { echo "== $1 run $4 | load $(cut -d' ' -f1 /proc/loadavg)" >> "$LOG"
  nice -n 10 timeout 1800 "$TW_ROOT/$2/julia" -t 1 --startup-file=no --project="$3" "$W/plain.jl" "$CSVFILE" $5 2>&1 | grep -v "^ *$" | cut -c1-300 | head -12 >> "$LOG"; }
for i in w $(seq "$runs"); do
  one V julia-vanilla $W/env_up $i none
  one N julia-next $W/env_up $i none
  one W wt/w156-julia $W/env_up $i none
  one W-first wt/w156-julia $H/../w161/env_lib $i first
  one W-late wt/w156-julia $H/../w161/env_lib $i late
done
echo "# done $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg)" >> "$LOG"
