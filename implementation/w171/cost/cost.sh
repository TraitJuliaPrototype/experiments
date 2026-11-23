#!/bin/bash
# W-171, second part (E-543): what the folds the rule "a set answer is not consistent" takes away (compiler §4.8; the
# inventory's row 187, with branch `w171b`'s additions) cost trait code. Two Julias on the same trait trees:
#   H  the head: branch w171b (wt/w171-julia), rows 185 to 188 and C-162 to C-165's fixes
#   B  the build before it: wt/w143-julia, d1e64d8b56 (rows 181 to 183; without rows 184 to 188)
# Cells: the library's load; the ODE port's program loaded, run first, run again (w169's session `ode`, the plain
# twin in the same setting as the control); E-513's calls through a trait (w159/calls_head.jl); POLLU's steady state
# (w169/stiff/run.jl, the port boxed and compiled). One warm-up process per cell and Julia (it writes the package
# images), then RUNS fresh processes per cell, H and B interleaved; the load before and after each.
#     bash cost.sh <label> [RUNS=3]          -> logs/cost-<label>.log
set -uo pipefail
C=$(cd "$(dirname "$0")" && pwd)
R=$(cd "$C/../../../.." && pwd)
source "$R/env.sh" >/dev/null 2>&1
IMPL=$R/experiments/implementation
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=1 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_GC_AUTO=false
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT JULIA_LOAD_PATH
ulimit -c 0
label=$1; RUNS=${2:-3}
LOG=$C/logs/cost-$label.log; mkdir -p "$C/logs"
# the depot and the control may be given: COST_DEPOT (default agent-depots/w171b), COST_B (a tree, default wt/w143-julia)
D=${COST_DEPOT:-$R/.julia-depot/agent-depots/w171b}
declare -A J=([H]=$R/wt/w171-julia [B]=$R/${COST_B:-wt/w143-julia})
ENV_DEMO=$IMPL/w159/envs/H/demo
load() { cut -d' ' -f1-3 /proc/loadavg; }
rev() { echo "$(git -C "$1" rev-parse --short=10 HEAD)$([ -z "$(git -C "$1" status --porcelain --untracked-files=no 2>/dev/null)" ] || echo '*')"; }
jl() { local s=$1; shift; mkdir -p "$D/$s"
  JULIA_DEPOT_PATH=$D/$s:$R/.julia-depot: nice -n 10 timeout -s KILL 900 "${J[$s]}/julia" --startup-file=no --history-file=no -t 1 "$@"; }
cell() { local s=$1 name=$2; shift 2
  case $name in
    lib)   jl $s --project="$R/TraitWorld" -e 't0 = time(); @eval using TraitWorld; println("R lib load_s ", time() - t0)' ;;
    ode|ode-plain)
           (cd "$IMPL/w169" && W169_MODE=time W169_APP=$IMPL/w135/apps/ode.jl ODE_PLAIN=$([ $name = ode ] && echo 0 || echo 1) VERIFY=0 \
              jl $s --project="$ENV_DEMO" "$IMPL/w169/tools/prof.jl" "$IMPL/w169/sessions/app.jl") ;;
    calls) jl $s --project="$R/TraitWorld" "$IMPL/w159/calls_head.jl" 10000000 ;;
    pollu-box)      jl $s --project="$ENV_DEMO" "$IMPL/w169/stiff/run.jl" port pollu 0 box ;;
    pollu-compiled) jl $s --project="$ENV_DEMO" "$IMPL/w169/stiff/run.jl" port pollu 0 compiled ;;
  esac; }
CELLS=${CELLS:-"lib ode ode-plain calls pollu-box pollu-compiled"}
{ echo "# E-543 cost $label | $(date -Is) | load $(load) | H $(rev ${J[H]}) ($("${J[H]}/julia" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')) | B $(rev ${J[B]}) | TraitWorld $(rev $R/TraitWorld) | TDE $(rev $R/TraitDifferentialEquations) | product setting, strict mode off, one thread, idiomatic trait code (the ODE program's plain twin: plain code on the build)"
  for c in $CELLS; do for s in H B; do
    out=$(cell $s $c 2>&1); echo "== warm-up $c $s | rc $? | load $(load)"; echo "$out" | grep -E 'ERROR|error:' | head -3
  done; done
  for i in $(seq "$RUNS"); do for c in $CELLS; do for s in H B; do
    l0=$(load); out=$(cell $s $c 2>&1); rc=$?
    echo "== run $i $c $s | rc $rc | load $l0 -> $(load)"
    echo "$out" | grep -q Precompiling && echo "# NOTE: precompiled in a timed run"
    echo "$out" | grep -vE 'Precompiling|✓|^\s*[0-9]+ dependenc' | head -60
  done; done; done
  echo "# done $(date -Is) | load $(load)"; } > "$LOG" 2>&1
