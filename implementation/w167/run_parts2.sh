#!/bin/bash
# W-167 (open issue 255): load_parts.jl at the ODE port's load for G, H and the tag B (the round's control), with and
# without Julia's invalidation log (W167_LOG=1, as w145/loads/load.jl runs it); a warm-up and N runs, interleaved.
#     bash run_parts2.sh <label> [N=3]     -> logs/parts-<label>.log
source "$(cd "$(dirname "$0")" && pwd)/round/lib.sh"
label=$1; N=${2:-3}; SETS="G H B"
header "$LOGS/parts-$label.log" "W-167 the ODE port's load in parts (load_parts.jl), log off and on" $SETS
declare -A E
for s in $SETS; do check $s; E[$s]=$(envfor $s "$IMPL/w134/env_demo" demo) || exit 1
  preflight $s "${E[$s]}" TraitWorld TraitDifferentialEquations; done
for r in w $(seq "$N"); do for lg in 0 1; do for s in $SETS; do
  export W167_LOG=$lg; CUT=400 HEAD=6 cell "$s log=$lg run $r" jl $s --project="${E[$s]}" "$W167/load_parts.jl" walk TraitDifferentialEquations || true
done; done; done
footer
