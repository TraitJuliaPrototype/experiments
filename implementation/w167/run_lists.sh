#!/bin/bash
# W-167: the two lists for a setting (round/lib.sh: H the freeze, G the library at W-167's worktree).
#     bash run_lists.sh <label> <S>...        -> logs/lists-<label>-<S>-<load>.txt, a summary in logs/lists-<label>.log
# The dynamic list (lib_ended.jl) at each load: the ODE port, the forks, NetworkDynamics, TraitMakie, TraitTables with
# TraitCSV, upstream CSV with DataFrames (unrelated: plain packages), and upstream again with the library loaded after
# it (LATE=1: E-515's late load). The static list (lib_static.jl) of the library alone, and after the ODE port's load.
# Every package's image must be valid (preflight): run round/prepare.sh first for G.
source "$(cd "$(dirname "$0")" && pwd)/round/lib.sh"
label=$1; shift
SUM="$LOGS/lists-$label.log"
header "$SUM" "W-167 lists ($label)" "$@"
for s in "$@"; do
  check "$s"
  demo=$(envfor "$s" "$IMPL/w134/env_demo" demo) || exit 1
  forks=$(envfor "$s" "$IMPL/w134/env_forks" forks) || exit 1
  lib=$(envfor "$s" "$IMPL/w134/env_lib" lib) || exit 1
  nd=$(envfor "$s" "$R/ndport/env_unified" ndtest) || exit 1
  tw=$(tree "$s" TW)
  preflight "$s" "$demo" TraitWorld TraitDifferentialEquations TraitMakie TraitTables TraitCSV
  preflight "$s" "$forks" TraitWorld CSV DataFrames; preflight "$s" "$lib" TraitWorld CSV DataFrames
  preflight "$s" "$nd" TraitWorld NetworkDynamics; preflight "$s" "$tw" TraitWorld
  run1() { local name=$1 env=$2 out="$LOGS/lists-$label-$s-$1.txt"; shift 2
    echo "== $s $name | load $(load)" >> "$SUM"
    jl "$s" --project="$env" "$W167/$1" "${@:2}" > "$out" 2>&1; local rc=$?
    grep -q Precompiling "$out" && die "$s $name precompiled: an image was stale or missing"
    grep '^# TraitWorld\|^ENDED\|^INSTANCES\|^HOOKS\|^OUTSIDE\|^STATIC' "$out" | cut -c1-300 >> "$SUM"
    echo "-- rc $rc | load $(load) | ${out#$R/}" >> "$SUM"; }
  run1 static "$tw" lib_static.jl
  run1 static-after-ode "$demo" lib_static.jl TraitDifferentialEquations
  run1 ode "$demo" lib_ended.jl TraitDifferentialEquations
  run1 forks "$forks" lib_ended.jl CSV DataFrames
  run1 nd "$nd" lib_ended.jl NetworkDynamics
  run1 makie "$demo" lib_ended.jl TraitMakie
  run1 tables "$demo" lib_ended.jl TraitTables TraitCSV
  run1 upstream "$lib" lib_ended.jl CSV DataFrames
  LATE=1 run1 upstream-late "$lib" lib_ended.jl CSV DataFrames
done
footer
