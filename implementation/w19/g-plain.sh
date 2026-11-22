#!/bin/bash
# W-19, third part: the plain load of upstream CSV and DataFrames (envs/up, no module with an option) on several
# builds, interleaved: the images made first, then a warm-up and RUNS fresh processes per build, one at a time,
# niced, one thread (motiv/f-plain.jl). With PROF=1 also RUNS profiled loads per build (motiv/g-profile.jl,
# logs/g-prof-<label>-<build>-<i>.tsv), and the counters (motiv/g-load-counts.jl) once per build.
#     bash g-plain.sh <label> <tree>...        -> logs/g-plain-<label>.log
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh" >/dev/null 2>&1
label=$1; shift; RUNS=${RUNS:-3}
export JULIA_DEPOT_PATH=$R/.julia-depot/agent-depots/w19-loads:$R/.julia-depot: JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_GC_AUTO=false
unset JULIA_COMPILE_BY_FACTS
CSV=$R/experiments/interfaces/App/data/sample.csv
LOG=$H/logs/g-plain-$label.log
J() { nice -n 10 "$R/$1/julia" --startup-file=no --history-file=no -t 1 --project="$H/envs/up" "${@:2}"; }
ver() { "$R/$1/julia" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)'; }
{ echo "# W-19 g-plain $label | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg) | runs $RUNS + warm-up"
  for T in "$@"; do echo "# $T: binary $(ver $T)"; J $T -e 'using Pkg; Pkg.precompile(); using CSV, DataFrames' 2>&1 | tail -2; done
  echo "images ready"
  for i in w $(seq "$RUNS"); do for T in "$@"; do
    echo "== $T run $i | load $(cut -d' ' -f1-3 /proc/loadavg)"
    out=$(J $T "$H/motiv/f-plain.jl" "$CSV" 2>&1); echo "$out" | tail -3
    echo "$out" | grep -q 'Precompiling' && echo "!! PRECOMPILED: an image was stale or missing"
  done; done
  if [ "${PROF:-0}" = 1 ]; then
    for i in $(seq "$RUNS"); do for T in "$@"; do
      b=$(basename "$T")
      echo "== profile $T run $i | load $(cut -d' ' -f1-3 /proc/loadavg)"
      J $T "$H/motiv/g-profile.jl" "$H/logs/g-prof-$label-$b-$i.tsv" 2>&1 | tail -2
    done; done
    for T in "$@"; do for m in edges inval; do
      echo "== counts $m $T | load $(cut -d' ' -f1-3 /proc/loadavg)"
      J $T "$H/motiv/g-load-counts.jl" $m 2>&1 | tail -30
    done; done
  fi
  echo "# done $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg)"
} 2>&1 | tee "$LOG"
