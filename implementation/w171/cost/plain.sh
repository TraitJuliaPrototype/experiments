#!/bin/bash
# W-171, fourth part (E-545): what the audit's fixes cost a session that uses no set. Upstream CSV and DataFrames
# compiled plainly (w19's envs/up; no module declares an option), on several Julia trees, each with a depot of its own
# (agent-depots/w171d/<name>). The images made first (`using CSV, DataFrames`), then a warm-up and RUNS fresh
# processes per tree, interleaved, of w19's motiv/f-plain.jl (the load, the first work, the session's code counts);
# with PROF=1 also RUNS processes per tree under the sampling profiler (prof-plain.jl: the load and the first work,
# logs/prof-<label>-<name>-<i>-{load,work}.tsv), compared with w19's tools/g-profcmp.py. One thread, niced, one
# process at a time.
#     bash plain.sh <label> <name>=<tree> ...           -> logs/plain-<label>.log
set -u; ulimit -c 0
C=$(cd "$(dirname "$0")" && pwd); R=$(cd "$C/../../../.." && pwd); source "$R/env.sh" >/dev/null 2>&1
IMPL=$R/experiments/implementation
label=$1; shift; RUNS=${RUNS:-3}
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_GC_AUTO=false
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT JULIA_LOAD_PATH
CSV=$R/experiments/interfaces/App/data/sample.csv
ENV=$IMPL/w19/envs/up
LOG=$C/logs/plain-$label.log; mkdir -p "$C/logs"
D=$R/.julia-depot/agent-depots/w171d
declare -A T; NAMES=()
for a in "$@"; do T[${a%%=*}]=$R/${a#*=}; NAMES+=("${a%%=*}"); done
load() { cut -d' ' -f1-3 /proc/loadavg; }
J() { local n=$1; shift; mkdir -p "$D/$n"
  JULIA_DEPOT_PATH=$D/$n:$R/.julia-depot: nice -n 10 timeout -s KILL 900 "${T[$n]}/julia" --startup-file=no --history-file=no -t 1 --project="$ENV" "$@"; }
{ echo "# E-545 plain $label | $(date -Is) | load $(load) | runs $RUNS + warm-up | upstream CSV, DataFrames compiled plainly; one thread; plain code"
  for n in "${NAMES[@]}"; do
    echo "# $n: ${T[$n]#$R/} $(git -C "${T[$n]}" rev-parse --short=10 HEAD) binary $(J $n -e 'print(Base.GIT_VERSION_INFO.commit_short)')"
    J $n -e 'using CSV, DataFrames' 2>&1 | tail -2
  done
  echo "images ready"
  for i in w $(seq "$RUNS"); do for n in "${NAMES[@]}"; do
    l0=$(load); out=$(J $n "$IMPL/w19/motiv/f-plain.jl" "$CSV" 2>&1)
    echo "== $n run $i | load $l0 -> $(load)"; echo "$out" | tail -2
    echo "$out" | grep -q 'Precompiling' && echo "!! PRECOMPILED: an image was stale or missing"
  done; done
  if [ "${PROF:-0}" = 1 ]; then
    for i in $(seq "$RUNS"); do for n in "${NAMES[@]}"; do
      l0=$(load); out=$(J $n "$C/prof-plain.jl" "$CSV" "$C/logs/prof-$label-$n-$i" 2>&1)
      echo "== profile $n run $i | load $l0 -> $(load)"; echo "$out" | tail -2
      echo "$out" | grep -q 'Precompiling' && echo "!! PRECOMPILED: an image was stale or missing"
    done; done
  fi
  echo "# done $(date -Is) | load $(load)"
} > "$LOG" 2>&1
cat "$LOG"
