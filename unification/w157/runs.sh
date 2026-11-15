#!/bin/bash
# W-157 (E-478's control): W-134's `lost.jl` (the work, the nine unrelated loads, the work again; order A) for
# upstream compiled by facts and the forks, a warm-up and <runs> fresh processes each, one at a time.
# JFLAGS="-J <image>" runs another system image on the same runtime (the baseline's, kept before a rebuild).
# Log: logs/<label>-runs.log.
#     [JFLAGS=...] bash runs.sh <label> [runs=2]
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"
L=$1; runs=${2:-2}; LOG=$H/logs/$L-runs.log; JF=${JFLAGS:-}
rev() { git -C "$1" log -1 --format=%h; }
echo "# $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-s3 $(rev $TW_ROOT/julia-s3) | JFLAGS '$JF' | TraitWorld-s3 $(rev $TW_ROOT/TraitWorld-s3) forks $(rev $TW_ROOT/forks-unified)" > "$LOG"
for env in env_facts env_forks; do
  for i in w $(seq "$runs"); do
    echo "== $env A run $i | load $(cut -d' ' -f1 /proc/loadavg)" >> "$LOG"
    nice -n 10 timeout 1800 $JS $JF --startup-file=no --project="$H/$env" "$TW_ROOT/experiments/unification/w134/lost.jl" A "$CSVFILE" $LOADS 2>&1 | grep -v "^ *$" | cut -c1-1500 | head -40 >> "$LOG"
  done
done
echo "# done $(date -Is)" >> "$LOG"
