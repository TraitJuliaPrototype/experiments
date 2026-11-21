#!/bin/bash
# W-159, G-1: E-391 and E-379's prompt rows: at a demonstrator's prompt, after the session's work, a new type, a new
# closure, an edit (the definition-time check at each edit, GT-12). Kinds: T (the table session), Tp (its plain twin
# on the same build: the baseline), D (the ODE session). The harness: w134/repl.jl, unchanged (env_demo).
#     bash g1_edit.sh <label> [RUNS=2]       SETTINGS="H B" KINDS="T Tp D"
# -> logs/g1-edit-<label>.log. About 5 minutes.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; RUNS=${2:-2}; SETTINGS=${SETTINGS:-H B}
CSV=$R/TraitReport/data/sensors.csv; OUT=$(mktemp -d)
header "$LOGS/g1-edit-$label.log" "G-1 E-391 an edit at the prompt (w134/repl.jl)" $SETTINGS
declare -A E
for s in $SETTINGS; do check $s; E[$s]=$(envfor $s "$IMPL/w134/env_demo" demo) || exit 1
  preflight $s "${E[$s]}" TraitWorld TraitTables TraitCSV TraitMakie TraitDifferentialEquations PlainTables PlainODE PlainPlots; done
for i in w $(seq "$RUNS"); do for k in ${KINDS:-T Tp D}; do for s in $SETTINGS; do
  TO=900 CUT=420 HEAD=80 cell "$s $k run $i" jl $s --project="${E[$s]}" "$IMPL/w134/repl.jl" $k "$CSV" "$OUT" || true
done; done; done
rm -rf "$OUT"; footer
