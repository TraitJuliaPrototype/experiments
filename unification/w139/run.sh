#!/bin/bash
# E-364: bash run.sh [tag] -- each app in a session, built with --trim=safe, and run; the outputs
# compared. Writes logs/run[-tag].log; the build logs are logs/<name>.build.log.
set -u
H=$(cd "$(dirname "$0")" && pwd); cd "$H"; R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
tag=${1:+-$1}; LOG=$H/logs/run$tag.log
rev() { git -C "$R/$1" log -1 --format=%h; }
echo "# E-364 $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified $(rev julia-unified) julia-vanilla $(rev julia-vanilla) TraitWorld-unified $(rev TraitWorld-unified)" > "$LOG"
one() { # one <app> <tree>
  local app=$1 tree=$2 name=$1-$2 proj=$R/TraitWorld-unified; [ "$tree" = julia-vanilla ] && proj=$H
  local ses bin=- same=-
  ses=$(JULIA_PKG_OFFLINE=true nice -n 10 "$R/$tree/julia" -t 1 --startup-file=no --project=$proj -e 'include(ARGS[1]); exit(main(String[]))' apps/$app.jl 2>&1)
  rm -f out/$name out/$name-o.a
  NAME=$name TRIM=${TRIM:-safe} JULIA_TREE=$tree bash build.sh $app $proj > /dev/null 2>&1
  if [ -x out/$name ]; then b=$(timeout 60 out/$name 2>&1); bin=$?; [ "$b" = "$ses" ] && same=yes || same=no; fi
  echo "$name | $(python3 summarize.py logs/$name.build.log | head -1 | sed 's/^[^:]*: //') | binary exit $bin | output equal: $same" | tee -a "$LOG"
  [ "$bin" != - ] && [ "$bin" != 0 ] && echo "$b" | head -4 | cut -c1-240 | sed 's/^/    /' >> "$LOG"
  ROOTS=3 python3 summarize.py logs/$name.build.log | tail -n +2 | head -6 >> "$LOG"
}
U=julia-unified; V=julia-vanilla
for a in typed vector; do one ${a}_trait $U; one ${a}_plain $U; one ${a}_plain $V; done
one dynamic_trait $U
one family_trait $U
one barrier_trait $U
