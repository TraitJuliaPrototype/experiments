#!/bin/bash
# W-161, E-501: E-372's sessions (W-120's `sessions.sh`) on the head and the baseline, the same day: the table and
# the ODE session, each a fresh process, a warm-up and N runs: the wall time, the marks, what the session
# compiles (W-120's classify_trace.py on the last run).
#   head:     julia-next with D-2, TraitWorld-unified, the ODE port's tree (env_head_demo)
#   baseline: julia-unified, TraitWorld-base, the ODE port at its tag prototype-2026-11, as TraitWorld-base (wt/w161-tde-base; env_base_demo)
#     bash sessions.sh head|base [N=3]      -> logs/sessions-<which>.log, logs/<app>-<which>.trace
set -u
H=$(cd "$(dirname "$0")" && pwd); source "$H/../env.sh"
which=$1; N=${2:-3}; U=$TW_ROOT/experiments/unification
case $which in
  head) J=$JN; ENVD=$H/env_head_demo; TDE=TraitDifferentialEquations-unified; TW=TraitWorld-unified ;;
  base) J=$JU; ENVD=$H/env_base_demo; TDE=wt/w161-tde-base; TW=TraitWorld-base ;;
esac
LOG=$H/logs/sessions-$which.log
rev() { git -C "$TW_ROOT/$1" log -1 --format=%h; }
dirty() { git -C "$TW_ROOT/$1" diff --quiet HEAD -- . 2>/dev/null || echo +dirty; }
D=$(mktemp -d); awk 'BEGIN { print "id,x,y,name"; for (i = 1; i <= 500; i++) printf "%d,%.3f,%.3f,n%d\n", i, i*0.1, 100-i*0.05, i%7 }' > "$D/t.csv"
echo "# E-501 sessions $which $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $(basename $(dirname $J)) $(git -C $(dirname $J) log -1 --format=%h)$(git -C $(dirname $J) diff --quiet HEAD -- src base Compiler || echo +dirty) TraitWorld $(rev $TW) TraitTables $(rev TraitTables-unified) TraitCSV $(rev TraitCSV-unified) TDE $(rev $TDE)$(dirty $TDE)" | tee "$LOG"
for app in table ode; do
  args=""; [ $app = table ] && args="$D/t.csv"
  for r in $(seq 0 $N); do
    s=$(date +%s.%N)
    line=$(VERIFY=0 nice -n 10 $J -t 1 --startup-file=no --project=$ENVD --trace-compile=$H/logs/$app-$which.trace --trace-compile-timing $U/w120/session_marks.jl $U/w135/apps/$app.jl $args 2>&1 | grep -E "^load |ERROR" | tail -1)
    e=$(date +%s.%N)
    [ $r = 0 ] && continue          # the warm-up: it writes the packages' images where they are stale
    echo "$app run $r: wall $(echo "$e - $s" | bc | cut -c1-5) s | load $(cut -d' ' -f1 /proc/loadavg) | $line" | tee -a "$LOG"
  done
  python3 $U/w120/classify_trace.py $H/logs/$app-$which.trace | tee -a "$LOG"
done
rm -rf "$D"
