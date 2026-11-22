#!/bin/bash
# W-19, second part: E-392's nine unrelated loads (w134/lost.jl, unchanged) on one build: upstream CSV and DataFrames
# compiled plainly (envs/up) and by facts with one line per module (envs/facts: w134's copies with the line
# `@compiler_options facts=true` alone, pkgs-facts-w19). Orders A (the work, the loads, the work again) and B (the
# loads, then the work). A warm-up and RUNS fresh processes per cell, one at a time, niced, one thread.
#     bash f-loads.sh <tree> <label> [RUNS=2]   -> logs/f-loads-<label>.log
#     PREP=1 bash f-loads.sh <tree> <label>       precompile both environments first (the depot below)
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh" >/dev/null 2>&1
T=$1; label=$2; RUNS=${3:-2}
export JULIA_DEPOT_PATH=$R/.julia-depot/agent-depots/w19-loads:$R/.julia-depot: JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_GC_AUTO=false
unset JULIA_COMPILE_BY_FACTS
J="nice -n 10 $R/$T/julia --startup-file=no --history-file=no -t 1"
CSV=$R/experiments/interfaces/App/data/sample.csv
LOADS="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"
LOG=$H/logs/f-loads-$label.log
if [ "${PREP:-0}" = 1 ]; then
  for e in up facts; do
    echo "# precompile envs/$e on $T $(git -C $R/$T log -1 --format=%h) | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg)"
    /usr/bin/time -f "%e s wall" $J --project=$H/envs/$e -e 'using Pkg; Pkg.precompile(); println("done")' 2>&1 | tail -3
  done
  exit 0
fi
{ echo "# W-19 f-loads | $T $(git -C $R/$T log -1 --format=%h) (binary $($R/$T/julia --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')) | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg) | runs $RUNS + warm-up"
  for i in w $(seq "$RUNS"); do for e in up facts; do for o in A B; do
    echo "== $e $o run $i | load $(cut -d' ' -f1-3 /proc/loadavg)"
    out=$($J --project=$H/envs/$e $R/experiments/implementation/w134/lost.jl $o $CSV $LOADS 2>&1); rc=$?
    echo "$out" | grep -v '^ *$' | cut -c1-1500 | head -40
    echo "$out" | grep -q 'Precompiling' && echo "!! PRECOMPILED: an image was stale or missing"
    echo "-- rc $rc"
  done; done; done
  echo "# done $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg)"; } > $LOG 2>&1
grep -E '^(==|order|work|the loads|image code|made by)' $LOG | head -80
