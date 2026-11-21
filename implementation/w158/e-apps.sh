#!/bin/bash
# W-158, third part (E-510): bash e-apps.sh <label> <tree> [app ...] -- each small program of this part (apps/e-*.jl,
# and apps/choice.jl, apps/flow.jl) in a session and trimmed (build_app.sh, --trim=safe), with the library at
# wt/w158b-tw; the binary run and its output compared with the session's. Log: logs/e-apps-<label>.log; build logs
# logs/e-<label>-<app>.build.log. One job at a time, niced; no core file.
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; R=$TW_ROOT
L=$1; T=$2; shift 2
APPS=${@:-e-boxcall e-ctor2 e-twochoice choice flow}
P=$R/wt/w158b-tw; LOG=$H/logs/e-apps-$L.log
echo "# W-158 e-apps $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $T $(git -C $R/$T log -1 --format=%h) library wt/w158b-tw $(git -C $P log -1 --format=%h)" | tee -a "$LOG"
for app in $APPS; do
  name=e-$L-$app
  ses=$(cd $P && nice -n 10 $R/$T/julia -t 1 --startup-file=no --project=$P -e 'include(ARGS[1]); exit(main(String[]))' $H/apps/$app.jl 2>&1)
  rm -f $H/out/$name
  bash $H/build_app.sh $T $H/apps/$app.jl $name $P > /dev/null 2>&1
  errs=$(grep -c '^Error #' $H/logs/$name.build.log)
  bin=-; same=-; size=-
  if [ -x $H/out/$name ]; then size=$(stat -c %s $H/out/$name); b=$(timeout 60 $H/out/$name 2>&1); bin=$?; [ "$b" = "$ses" ] && same=yes || same=no; fi
  echo "$app | errors $errs | binary $size bytes, exit $bin | output equal: $same" | tee -a "$LOG"
  echo "$ses" | sed 's/^/    session: /' | head -6 >> "$LOG"
  [ "$same" = no ] && echo "$b" | head -6 | cut -c1-240 | sed 's/^/    binary:  /' >> "$LOG"
  rm -f $H/out/$name
done
echo "# load after $(cut -d' ' -f1-3 /proc/loadavg)" | tee -a "$LOG"
