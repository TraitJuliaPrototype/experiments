#!/bin/bash
# W-155 (E-419 (a)): E-393's control on a tree: W-134's `lost.jl` (the work, nine unrelated loads, the work
# again; order A) for upstream compiled by facts and the forks, a warm-up and <runs> fresh processes each,
# one at a time. Log: logs/<label>-runs.log.
#     bash runs.sh <julia tree> <label> [runs=2]
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"
T=$TW_ROOT/$1; L=$2; runs=${3:-2}; J=$T/julia; LOG=$H/logs/$L-runs.log
rev() { git -C "$1" log -1 --format=%h; }
echo "# $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $1 $(rev $T) | TraitWorld-w155 $(rev $TW_ROOT/TraitWorld-w155) forks $(rev $TW_ROOT/forks-unified)" > "$LOG"
for env in env_facts env_forks; do
  for i in w $(seq "$runs"); do
    echo "== $env A run $i | load $(cut -d' ' -f1 /proc/loadavg)" >> "$LOG"
    nice -n 10 timeout 1800 "$J" --startup-file=no --project="$H/$env" "$TW_ROOT/experiments/unification/w134/lost.jl" A "$CSVFILE" $LOADS 2>&1 | grep -v "^ *$" | cut -c1-1500 | head -40 >> "$LOG"
  done
done
echo "# done $(date -Is)" >> "$LOG"
