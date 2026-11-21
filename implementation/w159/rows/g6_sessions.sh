#!/bin/bash
# W-159, G-6 and G-1: E-387's session cost and open issue 228: E-372's table and ODE sessions (w120/session_marks.jl
# with w135/apps/<app>.jl; E-501's pairing), H and B interleaved, a warm-up and N runs: the wall time, the marks
# (the load, the first run), what the last run compiles by class (w120/classify_trace.py). The ODE session's first
# run is open issue 228's case: TraitRodas._rodas5_run at the session's integrator compiled in the session.
#     bash g6_sessions.sh <label> [N=3]        -> logs/g6-sessions-<label>.log. About 2 minutes.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; N=${2:-3}; SETTINGS=${SETTINGS:-H B}
header "$LOGS/g6-sessions-$label.log" "G-6 E-387 and open issue 228: the table and the ODE sessions (w120/session_marks.jl)" $SETTINGS
declare -A E
for s in $SETTINGS; do check $s; E[$s]=$(envfor $s "$IMPL/w134/env_demo" demo) || exit 1
  preflight $s "${E[$s]}" TraitWorld TraitTables TraitCSV TraitDifferentialEquations; done
T=$(mktemp -d); awk 'BEGIN { print "id,x,y,name"; for (i = 1; i <= 500; i++) printf "%d,%.3f,%.3f,n%d\n", i, i*0.1, 100-i*0.05, i%7 }' > "$T/t.csv"
for app in table ode; do args=""; [ $app = table ] && args="$T/t.csv"
  for r in $(seq 0 $N); do for s in $SETTINGS; do
    tr=$LOGS/g6-sessions-$label-$app-$s.trace; t0=$(date +%s.%N)
    out=$(VERIFY=0 TO=600 jl $s --project="${E[$s]}" --trace-compile="$tr" --trace-compile-timing "$IMPL/w120/session_marks.jl" "$IMPL/w135/apps/$app.jl" $args 2>&1)
    echo "$out" | grep -q Precompiling && die "$s $app precompiled: an image was stale or missing"
    [ $r = 0 ] && continue
    echo "$s $app run $r: wall $(echo "$(date +%s.%N) - $t0" | bc | cut -c1-5) s | load $(load) | $(echo "$out" | grep -E '^load |ERROR' | tail -1)" >> "$LOG"
  done; done
  for s in $SETTINGS; do echo "# $s $app, the last run's compiles:" >> "$LOG"; python3 "$IMPL/w120/classify_trace.py" "$LOGS/g6-sessions-$label-$app-$s.trace" >> "$LOG" 2>&1; done
done
rm -rf "$T"; footer
