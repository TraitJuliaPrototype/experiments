#!/bin/bash
# W-167 (open issue 255): the ODE port's load in parts (load_parts.jl), walk and nowalk, per setting; a warm-up and N
# runs, interleaved; then one profiled load per setting (w159/probes/load_profile.jl).
#     bash run_parts.sh <label> [N=3] [S...=G H]     -> logs/parts-<label>.log, logs/parts-<label>-profile-<S>.txt
source "$(cd "$(dirname "$0")" && pwd)/round/lib.sh"
label=$1; N=${2:-3}; shift 2; SETS=${*:-G H}
header "$LOGS/parts-$label.log" "W-167 the ODE port's load in parts (load_parts.jl)" $SETS
declare -A E
for s in $SETS; do check $s; E[$s]=$(envfor $s "$IMPL/w134/env_demo" demo) || exit 1
  preflight $s "${E[$s]}" TraitWorld TraitDifferentialEquations; done
for r in w $(seq "$N"); do for mode in walk nowalk; do for s in $SETS; do
  CUT=400 HEAD=6 cell "$s $mode run $r" jl $s --project="${E[$s]}" "$W167/load_parts.jl" $mode TraitDifferentialEquations || true
done; done; done
for s in $SETS; do
  jl $s --project="${E[$s]}" "$W159/probes/load_profile.jl" TraitDifferentialEquations > "$LOGS/parts-$label-profile-$s.txt" 2>&1
  echo "# profile $s: ${LOGS#$R/}/parts-$label-profile-$s.txt | load $(load)" >> "$LOG"
done
footer
