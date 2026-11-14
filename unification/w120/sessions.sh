#!/bin/bash
# W-120, phase 3's first step: the table and the ODE sessions, each a fresh process, a warm-up and
# N runs: the wall time, the marks, what the session compiles (classify_trace.py on the last run).
#     bash sessions.sh [tag] [N]      -> logs/sessions[-tag].log, logs/<app>[-tag].trace
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
tag=${1:+-$1}; N=${2:-3}
J=$R/julia-unified/julia; ENVD=$H/../w134/env_demo; LOG=$H/logs/sessions$tag.log
rev() { git -C "$R/$1" log -1 --format=%h; }
D=$(mktemp -d); awk 'BEGIN { print "id,x,y,name"; for (i = 1; i <= 500; i++) printf "%d,%.3f,%.3f,n%d\n", i, i*0.1, 100-i*0.05, i%7 }' > "$D/t.csv"
echo "# W-120 sessions $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified $(rev julia-unified) TraitWorld $(rev TraitWorld-unified) TraitTables $(rev TraitTables-unified) TraitCSV $(rev TraitCSV-unified) TDE $(rev TraitDifferentialEquations-unified)" | tee "$LOG"
for app in table ode; do
  args=""; [ $app = table ] && args="$D/t.csv"
  for r in $(seq 0 $N); do
    s=$(date +%s.%N)
    line=$(VERIFY=0 JULIA_PKG_OFFLINE=true nice -n 10 $J -t 1 --startup-file=no --project=$ENVD --trace-compile=$H/logs/$app$tag.trace --trace-compile-timing $H/session_marks.jl $H/../w135/apps/$app.jl $args 2>/dev/null | grep "^load " | tail -1)
    e=$(date +%s.%N)
    [ $r = 0 ] && continue          # the warm-up: it writes the packages' images where they are stale
    echo "$app run $r: wall $(echo "$e - $s" | bc | cut -c1-5) s | $line" | tee -a "$LOG"
  done
  python3 $H/classify_trace.py $H/logs/$app$tag.trace | tee -a "$LOG"
done
rm -rf "$D"
