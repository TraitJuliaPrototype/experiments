#!/bin/bash
# W-158 (E-510), the main session's check after a merge: bash m-builds.sh <label> [app ...] -- the four demonstrators'
# programs (../w135/apps: table report plot ode) trimmed by ../w166/build_c.sh on julia-next with the project
# ../w156/env_demo (the library at TraitWorld/, the port at TraitDifferentialEquations/), each binary run and its
# output (and PNG) compared with a session's. Logs: logs/m-builds-<label>.log, build logs logs/w166c-m-<label>-<app>.*.
# One job at a time, niced; no core file. (As f-builds.sh, which builds with the library of a worktree.)
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; R=$TW_ROOT
L=$1; shift; APPS=${@:-table report plot ode}; T=julia-next
LOG=$H/logs/m-builds-$L.log; P=$R/experiments/implementation/w156/env_demo; W=$R/experiments/implementation/w166; O=$(mktemp -d)
D=$(mktemp -d); awk 'BEGIN { print "id,x,y,name"; for (i = 1; i <= 500; i++) printf "%d,%.3f,%.3f,n%d\n", i, i*0.1, 100-i*0.05, i%7 }' > "$D/t.csv"
CSV=$R/experiments/interfaces/App/data/sample.csv
rev() { git -C $R/$1 log -1 --format=%h; }
echo "# W-158 m-builds $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $T $(rev $T) TraitWorld $(rev TraitWorld) TraitDifferentialEquations $(rev TraitDifferentialEquations)$(git -C $R/TraitDifferentialEquations diff --quiet || echo +dirty) TraitMakie $(rev TraitMakie) TraitTables $(rev TraitTables)" | tee -a "$LOG"
for app in $APPS; do
  sargs=; bargs=
  case $app in
    table)  sargs="$D/t.csv"; bargs="$D/t.csv" ;;
    report) sargs="$CSV $D/s.png"; bargs="$CSV $D/b.png" ;;
    plot)   sargs="$D/s.png"; bargs="$D/b.png" ;;
  esac
  rm -f $D/s.png $D/b.png
  ses=$(cd $D && nice -n 10 $R/$T/julia -t 1 --startup-file=no --project=$P -e 'include(ARGS[1]); exit(main(ARGS[2:end]))' $R/experiments/implementation/w135/apps/$app.jl $sargs 2>&1 | sed "s|$D/s.png|OUT.png|")
  JULIA_TREE=$T DEPOT=$R/.julia-depot/agent-depots/w158 NAME=m-$L-$app LOGDIR=$H/logs OUTDIR=$O bash $W/build_c.sh $app $P > /dev/null 2>&1
  BL=$H/logs/w166c-m-$L-$app.build.log; errs=$(grep -c '^Error #' $BL); bin=-; same=-; png=-; size=-
  if [ -x $O/w166c-m-$L-$app ]; then
    size=$(stat -c %s $O/w166c-m-$L-$app)
    b=$(cd $D && timeout 120 $O/w166c-m-$L-$app $bargs 2>$D/err | sed "s|$D/b.png|OUT.png|"); bin=$?
    [ "$b" = "$ses" ] && same=yes || same=no
    [ -f $D/s.png ] && [ -f $D/b.png ] && { cmp -s $D/s.png $D/b.png && png=equal || png=differ; }
    echo "$b" > $H/logs/m-$L-$app.bin.out; echo "$ses" > $H/logs/m-$L-$app.session.out
  fi
  echo "$app | errors $errs | $(grep -E '^(object|link):' $BL | tr '\n' ' ')| $size bytes | binary exit $bin | output equal: $same | PNG: $png" | tee -a "$LOG"
  [ "$bin" != - ] && [ "$bin" != 0 ] && head -5 $D/err | cut -c1-240 | sed 's/^/    /' | tee -a "$LOG"
  [ "$same" = no ] && { echo "$b" | head -4 | sed 's/^/    binary:  /'; echo "$ses" | head -4 | sed 's/^/    session: /'; } | tee -a "$LOG"
  rm -f $O/w166c-m-$L-$app
done
echo "# load after $(cut -d' ' -f1-3 /proc/loadavg)" | tee -a "$LOG"
rm -rf "$D" "$O"
