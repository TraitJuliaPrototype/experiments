#!/bin/bash
# W-168, G-6 and open issue 256 (b): what the check of a program costs in a session. `probes/check_cost.jl`:
# the program (the table's, the ODE's; VERIFY=0) loaded, then TraitWorld.verify_main or TraitWorld.fully_typed at
# its `main` timed twice in the same process, then the walk and the build's own check apart. 3 fresh processes per
# cell, the head only (the plain baseline has no check: a count of what the check does is in the log's `split`).
#     bash g6_check.sh <label> [N=3]        -> logs/g6-check-<label>.log. About 3 minutes.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; N=${2:-3}; SETTINGS=${SETTINGS:-H}
header "$LOGS/g6-check-$label.log" "G-6 open issue 256 (b): the check's cost in a session (probes/check_cost.jl)" $SETTINGS
declare -A E
for s in $SETTINGS; do check $s; E[$s]=$(envfor $s "$IMPL/w134/env_demo" demo) || exit 1
  preflight $s "${E[$s]}" TraitWorld TraitTables TraitCSV TraitDifferentialEquations; done
T=$(mktemp -d); awk 'BEGIN { print "id,x,y,name"; for (i = 1; i <= 500; i++) printf "%d,%.3f,%.3f,n%d\n", i, i*0.1, 100-i*0.05, i%7 }' > "$T/t.csv"
for app in table ode; do args=""; [ $app = table ] && args="$T/t.csv"
  for mode in verify fully; do for r in $(seq 1 $N); do for s in $SETTINGS; do
  echo "== $s $app $mode run $r | load $(load)" >> "$LOG"
  out=$(VERIFY=0 ODE_PLAIN=0 TO=900 jl $s --project="${E[$s]}" "$IMPL/w159/probes/check_cost.jl" $mode "$IMPL/w135/apps/$app.jl" $args 2>&1)
  echo "$out" | grep -q Precompiling && die "$s $app precompiled: an image was stale or missing"
  echo "$out" | grep -E '^(first|second|split)|ERROR|Error' | cut -c1-400 >> "$LOG"
  echo "-- load $(load)" >> "$LOG"
done; done; done; done
rm -rf "$T"; footer
