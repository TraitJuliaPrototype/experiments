#!/bin/bash
# W-158 (E-510): W-166's copy of W-156's regression control (../w156/sessions.sh) with this directory's depot and logs. The demonstrators' sessions as E-389 ran them (W-120's harness,
# `../w120/sessions.sh`), on julia-next: the report (TraitCSV, TraitTables, TraitMakie: `../w135/apps/report.jl`
# on the task's file) and the table session (TraitCSV, TraitTables: `../w135/apps/table.jl`, 500 rows). Each a
# fresh process with one thread, niced; a warm-up (it writes the packages' images where they are stale) and N
# runs; the marks of `../w120/session_marks.jl`; what the session compiles, by class (`../w120/classify_trace.py`
# on the last run's trace).
#     [TREE=<julia tree>] bash sessions.sh <tag> [N]        -> logs/sessions-<tag>.log, logs/<app>-<tag>.trace
set -u
H=$(cd "$(dirname "$0")" && pwd)
# TREE=<julia tree> (relative to the workspace root) runs with that tree's binary and the third part's depot
# (env-c.sh); the default is julia-next with the second part's (env.sh)
# ENVD=<environment> replaces env_demo (env_demo_next: env_demo with the library at `unified` from wt/w156c-tw, for julia-next)
source "$H/env.sh"; TREE=${TREE:-julia-next}; JN=$TW_ROOT/$TREE/julia
tag=$1; N=${2:-3}
U=$H/..; ENVD=${ENVD:-$W156/env_demo}; LOG=$H/logs/sessions-$tag.log
rev() { git -C "$TW_ROOT/$1" log -1 --format=%h; }
D=$(mktemp -d); awk 'BEGIN { print "id,x,y,name"; for (i = 1; i <= 500; i++) printf "%d,%.3f,%.3f,n%d\n", i, i*0.1, 100-i*0.05, i%7 }' > "$D/t.csv"
CSV=$TW_ROOT/experiments/interfaces/App/data/sample.csv
echo "# W-158 sessions $tag $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $TREE $(rev $TREE) TraitWorld $(rev TraitWorld) TraitTables $(rev TraitTables) TraitCSV $(rev TraitCSV) TraitMakie $(rev TraitMakie)" | tee "$LOG"
for app in report table; do
  if [ $app = report ]; then args="$CSV $D/r.png"; else args="$D/t.csv"; fi
  for r in $(seq 0 $N); do
    s=$(date +%s.%N)
    line=$(VERIFY=0 nice -n 10 $JN -t 1 --startup-file=no --project=$ENVD --trace-compile=$H/logs/$app-$tag.trace --trace-compile-timing $U/w120/session_marks.jl $U/w135/apps/$app.jl $args 2>/dev/null | grep "^load " | tail -1)
    e=$(date +%s.%N)
    [ $r = 0 ] && continue
    echo "$app run $r: wall $(echo "$e - $s" | bc | cut -c1-5) s | $line" | tee -a "$LOG"
  done
  python3 $U/w120/classify_trace.py $H/logs/$app-$tag.trace | sed "s|$TW_ROOT/||" | tee -a "$LOG"
done
echo "# load after $(cut -d' ' -f1-3 /proc/loadavg)" | tee -a "$LOG"
rm -rf "$D"
# the compiled instances the session's packages hold after one run of `main` (instances.jl)
D=$(mktemp -d); awk 'BEGIN { print "id,x,y,name"; for (i = 1; i <= 500; i++) printf "%d,%.3f,%.3f,n%d\n", i, i*0.1, 100-i*0.05, i%7 }' > "$D/t.csv"
for app in report table; do
  if [ $app = report ]; then args="$CSV $D/r.png"; else args="$D/t.csv"; fi
  nice -n 10 $JN -t 1 --startup-file=no --project=$ENVD $W156/instances.jl $U/w135/apps/$app.jl $args 2>/dev/null | grep '^instances' | sed "s/^/$app /" | tee -a "$LOG"
done
rm -rf "$D"
