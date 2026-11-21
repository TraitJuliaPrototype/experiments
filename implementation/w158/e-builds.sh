#!/bin/bash
# W-158, third part (E-510): bash e-builds.sh <label> <tree> [app ...] -- the table's, the report's and the plot's
# programs (../w135/apps) trimmed by ../w166/build_c.sh with project env_demo_d (the library at wt/w158b-tw) and this
# part's depot, each binary run and its output (and PNG) compared with a session's. Logs: logs/e-builds-<label>.log,
# build logs ../w166/logs/w166c-e-<label>-<app>.*. One job at a time, niced; no core file.
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; R=$TW_ROOT
L=$1; T=$2; shift 2; APPS=${@:-table report plot}
LOG=$H/logs/e-builds-$L.log; P=$H/env_demo_d; W=$R/experiments/implementation/w166
D=$(mktemp -d); awk 'BEGIN { print "id,x,y,name"; for (i = 1; i <= 500; i++) printf "%d,%.3f,%.3f,n%d\n", i, i*0.1, 100-i*0.05, i%7 }' > "$D/t.csv"
CSV=$R/experiments/interfaces/App/data/sample.csv
echo "# W-158 e-builds $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $T $(git -C $R/$T log -1 --format=%h) library wt/w158b-tw $(git -C $R/wt/w158b-tw log -1 --format=%h)" | tee -a "$LOG"
for app in $APPS; do
  case $app in
    table)  sargs="$D/t.csv"; bargs="$D/t.csv" ;;
    report) sargs="$CSV $D/s.png"; bargs="$CSV $D/b.png" ;;
    plot)   sargs="$D/s.png"; bargs="$D/b.png" ;;
  esac
  rm -f $D/s.png $D/b.png
  ses=$(cd $D && nice -n 10 $R/$T/julia -t 1 --startup-file=no --project=$P -e 'include(ARGS[1]); exit(main(ARGS[2:end]))' $R/experiments/implementation/w135/apps/$app.jl $sargs 2>&1 | sed "s|$D/s.png|OUT.png|")
  JULIA_TREE=$T DEPOT=$R/.julia-depot/agent-depots/w158 TW=wt/w158b-tw NAME=e-$L-$app bash $W/build_c.sh $app $P > /dev/null 2>&1
  BL=$W/logs/w166c-e-$L-$app.build.log; errs=$(grep -c '^Error #' $BL); bin=-; same=-; png=-
  if [ -x $W/out/w166c-e-$L-$app ]; then
    b=$(cd $D && timeout 120 $W/out/w166c-e-$L-$app $bargs 2>$D/err | sed "s|$D/b.png|OUT.png|"); bin=$?
    [ "$b" = "$ses" ] && same=yes || same=no
    [ -f $D/s.png ] && [ -f $D/b.png ] && { cmp -s $D/s.png $D/b.png && png=equal || png=differ; }
  fi
  echo "$app | errors $errs | $(grep -E '^(object|link):' $BL | tr '\n' ' ')| binary exit $bin | output equal: $same | PNG: $png" | tee -a "$LOG"
  [ "$bin" != - ] && [ "$bin" != 0 ] && head -5 $D/err | cut -c1-240 | sed 's/^/    /' | tee -a "$LOG"
  [ "$same" = no ] && { echo "$b" | head -4 | sed 's/^/    binary:  /'; echo "$ses" | head -4 | sed 's/^/    session: /'; } | tee -a "$LOG"
  rm -f $W/out/w166c-e-$L-$app
done
echo "# load after $(cut -d' ' -f1-3 /proc/loadavg)" | tee -a "$LOG"
rm -rf "$D"
