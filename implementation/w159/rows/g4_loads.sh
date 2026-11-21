#!/bin/bash
# W-159, G-4: E-382 (w145/loads/load.jl, unchanged): the time of `using` for each port, Julia's invalidation log by
# event, the instances it ends by root module; TraitTables with TraitCSV also under strict mode (GT-2). Upstream's
# packages compiled plainly on the build and on vanilla are the baseline. MODES="walk nowalk" adds E-382's control
# without the membership walk's invalidation (default: walk only).
# Rows (as E-382's, one change: TraitMakie is loaded from env_demo, since the tag's TraitMakie tree carries no
# environment that resolves on its own): traitworld tables tables-strict ode makie forks upstream-facts upstream nd;
# upstream-vanilla on V. A warm-up and N runs per row and setting; the last run's events kept.
#     bash g4_loads.sh <label> [N=3]          -> logs/g4-loads-<label>.log. About 6 minutes (walk only).
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; N=${2:-3}; SETTINGS=${SETTINGS:-H B}
header "$LOGS/g4-loads-$label.log" "G-4 E-382 a port's load (w145/loads/load.jl), modes ${MODES:-walk}" $SETTINGS V
declare -A E
for s in $SETTINGS; do check $s
  for e in demo forks facts up nd; do
    case $e in nd) E[$s.$e]=$(envfor $s "$R/ndport/env_unified" ndtest) || exit 1 ;;
               *) E[$s.$e]=$(envfor $s "$IMPL/w134/env_$e" $e) || exit 1 ;; esac; done
  E[$s.tw]=$(tree $s TW); preflight $s "${E[$s.tw]}" TraitWorld
  preflight $s "${E[$s.demo]}" TraitTables TraitCSV TraitDifferentialEquations TraitMakie
  preflight $s "${E[$s.forks]}" CSV DataFrames; preflight $s "${E[$s.facts]}" CSV DataFrames
  preflight $s "${E[$s.up]}" CSV DataFrames; preflight $s "${E[$s.nd]}" NetworkDynamics; done
check V; E[V.up]=$(envfor V "$IMPL/w134/env_up" up) || exit 1; preflight V "${E[V.up]}" CSV DataFrames
row() { # row <name> <setting> <env key> <modes> <packages...>
  local name=$1 s=$2 env=${E[$2.$3]} modes=$4 mode r tmp; shift 4
  for mode in $modes; do for r in $(seq 0 $N); do
    tmp=$(mktemp)
    jl $s --project="$env" "$IMPL/w145/loads/load.jl" $mode "$@" > "$tmp" 2>&1
    grep -q Precompiling "$tmp" && { rm -f "$tmp"; die "$s $name precompiled: an image was stale or missing"; }
    [ $r = 0 ] || echo "$s $name run $r | load $(load) | $(grep '^LOAD' "$tmp" | cut -c6-)" >> "$LOG"
    [ $r = $N ] && grep 'EVENT\|ENDED' "$tmp" | sed "s/^/$s $name $mode/" >> "$LOG"
    grep -v '^LOAD\|EVENT\|ENDED' "$tmp" | head -3 | sed "s/^/$s $name !! /" >> "$LOG"; rm -f "$tmp"
  done; done; }
M=${MODES:-walk}
for s in $SETTINGS; do
  row traitworld $s tw "$M" TraitWorld
  row tables $s demo "$M" TraitTables TraitCSV
  JULIA_TW_STRICT=1 row tables-strict $s demo walk TraitTables TraitCSV
  row ode $s demo "$M" TraitDifferentialEquations
  row makie $s demo "$M" TraitMakie
  row forks $s forks "$M" CSV DataFrames
  row upstream-facts $s facts walk CSV DataFrames
  row upstream $s up walk CSV DataFrames
  row nd $s nd "$M" NetworkDynamics
done
row upstream-vanilla V up walk CSV DataFrames
footer
