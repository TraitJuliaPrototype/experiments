#!/bin/bash
# E-361: bash run_warn.sh [tag] -- every app built with --trim=unsafe-warn, each binary run, and its output
# compared with the same app's output in a session. Writes logs/run-warn[-tag].log; the build logs are
# logs/<name>.build.log. Builds run one after another.
set -u
H=$(cd "$(dirname "$0")" && pwd); cd "$H"; R=$(cd "$H/../../.." && pwd)
tag=${1:+-$1}; LOG=$H/logs/run-warn$tag.log; D=$H/out/data; mkdir -p "$D"
rev() { git -C "$R/$1" log -1 --format=%h; }
echo "# E-361 run_warn $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified $(rev julia-unified) julia-vanilla $(rev julia-vanilla) TraitWorld-unified $(rev TraitWorld-unified)" > "$LOG"
# the table's input: 500 rows, an Int column, two Float64 columns, a String column
awk 'BEGIN { print "id,x,y,name"; for (i = 1; i <= 500; i++) printf "%d,%.3f,%.3f,n%d\n", i, i*0.1, 100-i*0.05, i%7 }' > "$D/t.csv"
one() { # one <name> <app> <tree> <project or ""> <args...>   (the app's env is the caller's)
  local name=$1 app=$2 tree=$3 proj=$4; shift 4
  local bin=fail ses=fail same=-
  # the session first: it also writes the packages' images, which the build then loads (a build on a
  # depot without them loads the packages from source, and has crashed there: README)
  (cd "$D" && VERIFY=0 JULIA_TREE=$tree bash "$H/session.sh" $app "$proj" "$@" > "$name.ses.out" 2> "$name.ses.err"); ses=$?
  rm -f out/$name out/$name-o.a
  NAME=$name TRIM=unsafe-warn JULIA_TREE=$tree bash build.sh $app $proj > /dev/null 2>&1
  # (under unsafe-warn the verifier's report is cut off when the build process exits, on both Julias:
  # its counts are run_safe.sh's)
  local b="$(grep -ho 'object: exit.*\|link: exit.*' logs/$name.build.log | tr '\n' ' ')"
  if [ -x out/$name ]; then
    (cd "$D" && timeout 120 "$H/out/$name" "$@" > "$name.bin.out" 2> "$name.bin.err"); bin=$?
  fi
  [ "$bin" = 0 ] && { cmp -s "$D/$name.bin.out" "$D/$name.ses.out" && same=yes || same=no; }
  echo "$name | $b| binary exit $bin | session exit $ses | output equal: $same" | tee -a "$LOG"
  [ "$bin" != 0 ] && [ -s "$D/$name.bin.err" ] && head -6 "$D/$name.bin.err" | cut -c1-240 | sed 's/^/    /' >> "$LOG"
  [ "$bin" = 0 ] && sed 's/^/    /' "$D/$name.bin.out" | head -12 >> "$LOG"
}
U=julia-unified; V=julia-vanilla
one hello-warn hello $U ""
one jll-warn-unified jll $U "$H/env_jll"
one jll-warn-vanilla jll $V "$H/env_jll"
VERIFY=0 one table-warn-bare table $U "" t.csv
VERIFY=1 one table-warn-verify table $U "" t.csv
TABLE_PLAIN=1 one table-warn-plain table $U "" t.csv
TABLE_PLAIN=1 one table-warn-plain-vanilla table $V "" t.csv
VERIFY=0 one ode-warn-bare ode $U ""
VERIFY=1 one ode-warn-verify ode $U ""
VERIFY=0 ODE_AD=1 one ode-ad-warn-bare ode $U ""
VERIFY=1 ODE_AD=1 one ode-ad-warn-verify ode $U ""
VERIFY=0 one plot-warn-bare plot $U "" plot.png
VERIFY=1 one plot-warn-verify plot $U "" plot.png
one plot_plain-warn plot_plain $U "" plot.png
one plot_plain-warn-vanilla plot_plain $V "" plot.png
ODE_PLAIN=1 one ode-warn-plain ode $U ""
ODE_PLAIN=1 one ode-warn-plain-vanilla ode $V ""
