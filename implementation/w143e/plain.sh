#!/bin/bash
# W-143e (E-541; W-143d's plain.sh): plain code's first work (../w19/motiv/f-plain.jl: upstream CSV and DataFrames compiled plainly,
# envs/up, a copy of ../w19/envs/up) on Julia trees, interleaved: the images first, then a warm-up and RUNS fresh
# processes per tree, niced, one thread; a depot of this item's own per tree.   bash plain.sh <label> <tree>...
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh" >/dev/null 2>&1
label=$1; shift; RUNS=${RUNS:-3}
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_GC_AUTO=false
unset JULIA_COMPILE_BY_FACTS
CSV=$R/experiments/interfaces/App/data/sample.csv
LOG=$H/logs/plain-$label.log
J() { JULIA_DEPOT_PATH=$R/.julia-depot/agent-depots/w143e/$(basename $1)-up:$R/.julia-depot: nice -n 10 "$R/$1/julia" --startup-file=no --history-file=no -t 1 --project="$H/envs/up" "${@:2}"; }
ver() { "$R/$1/julia" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)'; }
{ echo "# W-143e plain $label | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg) | runs $RUNS + warm-up"
  for T in "$@"; do echo "# $T: binary $(ver $T)"; J $T -e 'using CSV, DataFrames' 2>&1 | tail -2; done
  echo "images ready"
  for i in w $(seq "$RUNS"); do for T in "$@"; do
    echo "== $T run $i | load $(cut -d' ' -f1-3 /proc/loadavg)"
    out=$(J $T "$R/experiments/implementation/w19/motiv/f-plain.jl" "$CSV" 2>&1); echo "$out" | tail -3
    echo "$out" | grep -q 'Precompiling' && echo "!! PRECOMPILED: an image was stale or missing"
  done; done
  echo "# done $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg)"
} 2>&1 | tee "$LOG"
