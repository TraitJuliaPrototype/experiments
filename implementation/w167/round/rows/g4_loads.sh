#!/bin/bash
# W-167: W-159's g4_loads.sh (E-516: a port's load, w145/loads/load.jl) with this directory's lib.sh, for the settings
# SETTINGS (default "G H") and the rows ROWS (default "traitworld ode forks nd"; also tables tables-strict makie
# upstream-facts upstream). A warm-up and N runs per row and setting; the last run's events kept.
#     bash g4_loads.sh <label> [N=3]          -> logs/g4-loads-<label>.log
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; N=${2:-3}; SETTINGS=${SETTINGS:-G H}; ROWS=${ROWS:-traitworld ode forks nd}
header "$LOGS/g4-loads-$label.log" "W-167 E-516 a port's load (w145/loads/load.jl), rows $ROWS, modes walk" $SETTINGS
declare -A E
for s in $SETTINGS; do check $s
  for e in demo forks facts up nd; do
    case $e in nd) E[$s.$e]=$(envfor $s "$R/ndport/env_unified" ndtest) || exit 1 ;;
               *) E[$s.$e]=$(envfor $s "$IMPL/w134/env_$e" $e) || exit 1 ;; esac; done
  E[$s.tw]=$(tree $s TW); preflight $s "${E[$s.tw]}" TraitWorld
  preflight $s "${E[$s.demo]}" TraitTables TraitCSV TraitDifferentialEquations TraitMakie
  preflight $s "${E[$s.forks]}" CSV DataFrames; preflight $s "${E[$s.nd]}" NetworkDynamics; done
row() { # row <name> <setting> <env key> <packages...>
  local name=$1 s=$2 env=${E[$2.$3]} r tmp; shift 3
  for r in $(seq 0 $N); do
    tmp=$(mktemp)
    jl $s --project="$env" "$IMPL/w145/loads/load.jl" walk "$@" > "$tmp" 2>&1
    grep -q Precompiling "$tmp" && { rm -f "$tmp"; die "$s $name precompiled: an image was stale or missing"; }
    [ $r = 0 ] || echo "$s $name run $r | load $(load) | $(grep '^LOAD' "$tmp" | cut -c6-)" >> "$LOG"
    [ $r = $N ] && grep 'EVENT\|ENDED' "$tmp" | sed "s/^/$s $name walk/" >> "$LOG"
    grep -v '^LOAD\|EVENT\|ENDED' "$tmp" | head -3 | sed "s/^/$s $name !! /" >> "$LOG"; rm -f "$tmp"
  done; }
for name in $ROWS; do for s in $SETTINGS; do
  case $name in
    traitworld) row traitworld $s tw TraitWorld ;;
    tables) row tables $s demo TraitTables TraitCSV ;;
    tables-strict) JULIA_TW_STRICT=1 row tables-strict $s demo TraitTables TraitCSV ;;
    ode) row ode $s demo TraitDifferentialEquations ;;
    makie) row makie $s demo TraitMakie ;;
    forks) row forks $s forks CSV DataFrames ;;
    upstream-facts) row upstream-facts $s facts CSV DataFrames ;;
    upstream) row upstream $s up CSV DataFrames ;;
    nd) row nd $s nd NetworkDynamics ;;
    *) die "row $name" ;;
  esac; done; done
footer
