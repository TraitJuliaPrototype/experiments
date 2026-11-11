#!/bin/bash
# E-361, the programs left by the first round: bash run_rest.sh -- upstream CSV with DataFrames (csvdf),
# TraitReport's task with its plot (report) beside its plain twin, and PlainODE on the unified build.
# Each under --trim=unsafe-warn (session, build, run, outputs compared) and --trim=safe (the verifier's
# report counted). Writes logs/rest-warn.log and logs/rest-safe.log. Builds run one after another.
set -u
H=$(cd "$(dirname "$0")" && pwd); cd "$H"; R=$(cd "$H/../../.." && pwd)
W=$H/logs/rest-warn.log; S=$H/logs/rest-safe.log; D=$H/out/data; mkdir -p "$D"
rev() { git -C "$R/$1" log -1 --format=%h; }
for L in "$W" "$S"; do
  echo "# E-361 run_rest $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified $(rev julia-unified) julia-vanilla $(rev julia-vanilla) TraitWorld-unified $(rev TraitWorld-unified)" > "$L"
done
awk 'BEGIN { print "id,x,y,name"; for (i = 1; i <= 500; i++) printf "%d,%.3f,%.3f,n%d\n", i, i*0.1, 100-i*0.05, i%7 }' > "$D/t.csv"
cp "$R/TraitReport-unified/data/sensors.csv" "$D/sensors.csv"
one() { # one <name> <app> <tree> <project or ""> <args...>   (the app's env is the caller's)
  local name=$1 app=$2 tree=$3 proj=$4; shift 4
  local bin=fail ses=fail same=-
  (cd "$D" && VERIFY=0 JULIA_TREE=$tree bash "$H/session.sh" $app "$proj" "$@" > "$name.ses.out" 2> "$name.ses.err"); ses=$?
  rm -f out/$name-warn out/$name-warn-o.a out/$name out/$name-o.a
  NAME=$name-warn TRIM=unsafe-warn JULIA_TREE=$tree bash build.sh $app $proj > /dev/null 2>&1
  local b="$(grep -ho 'object: exit.*\|link: exit.*' logs/$name-warn.build.log | tr '\n' ' ')"
  if [ -x out/$name-warn ]; then
    (cd "$D" && timeout 120 "$H/out/$name-warn" "$@" > "$name.bin.out" 2> "$name.bin.err"); bin=$?
  fi
  [ "$bin" = 0 ] && { cmp -s "$D/$name.bin.out" "$D/$name.ses.out" && same=yes || same=no; }
  echo "$name-warn | $b| binary exit $bin | session exit $ses | output equal: $same" | tee -a "$W"
  [ "$ses" != 0 ] && head -4 "$D/$name.ses.err" | cut -c1-240 | sed 's/^/    session: /' >> "$W"
  [ "$bin" != 0 ] && [ -s "$D/$name.bin.err" ] && head -6 "$D/$name.bin.err" | cut -c1-240 | sed 's/^/    /' >> "$W"
  [ "$bin" = 0 ] && sed 's/^/    /' "$D/$name.bin.out" | head -12 >> "$W"
  NAME=$name TRIM=safe JULIA_TREE=$tree bash build.sh $app $proj > /dev/null 2>&1
  ROOTS=4 python3 summarize.py logs/$name.build.log | tee -a "$S"
}
U=julia-unified; V=julia-vanilla; UP=$H/../w134/env_up
ODE_PLAIN=1 one ode-plain2 ode $U ""
one csvdf-unified csvdf $U "$UP" t.csv
one csvdf-vanilla csvdf $V "$UP" t.csv
VERIFY=0 one report-bare report $U "" sensors.csv report.png
VERIFY=1 one report-verify report $U "" sensors.csv report.png
REPORT_PLAIN=1 one report-plain report $U "" sensors.csv report.png
REPORT_PLAIN=1 one report-plain-vanilla report $V "" sensors.csv report.png
