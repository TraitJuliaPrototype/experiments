#!/bin/bash
# W-166 (E-507): E-384's eight small trait programs (../w139/apps) on a tree: each in a session, built with
# --trim=safe by ../w139/build.sh, and run; the outputs compared. One build at a time, niced; no core files.
#     bash small.sh <label> [tree]       -> logs/<label>-small.log; build logs ../w139/logs/w166-<label>-<app>.build.log
set -u
ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; R=$TW_ROOT
L=$1; T=${2:-julia-next}; LOG=$H/logs/$L-small.log; W=$H/../w139
rev() { git -C "$R/$1" log -1 --format=%h; }
echo "# W-166 small $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $T $(rev $T) TraitWorld $(rev TraitWorld)" | tee "$LOG"
for app in typed_trait vector_trait dynamic_trait family_trait barrier_trait ft_union ft_abstract_result ft_abstract_member; do
  name=w166-$L-$app; bin=-; same=-
  ses=$(nice -n 10 "$R/$T/julia" -t 1 --startup-file=no --project=$R/TraitWorld -e 'include(ARGS[1]); exit(main(String[]))' $W/apps/$app.jl 2>&1)
  rm -f $W/out/$name $W/out/$name-o.a
  NAME=$name TRIM=safe JULIA_TREE=$T bash $W/build.sh $app > /dev/null 2>&1
  if [ -x $W/out/$name ]; then b=$(timeout 60 $W/out/$name 2>&1); bin=$?; [ "$b" = "$ses" ] && same=yes || same=no; fi
  echo "$app | $(python3 $W/summarize.py $W/logs/$name.build.log | head -1 | sed 's/^[^:]*: //') | binary exit $bin | output equal: $same" | tee -a "$LOG"
  [ "$bin" != - ] && [ "$bin" != 0 ] && echo "$b" | head -4 | cut -c1-240 | sed 's/^/    /' >> "$LOG"
  rm -f $W/out/$name-o.a
done
echo "# load after $(cut -d' ' -f1-3 /proc/loadavg)" | tee -a "$LOG"
