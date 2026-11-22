#!/bin/bash
# W-19, third part: Base's test files on one build, `Base.runtests([...]; ncores=1)`, one worker per call, niced.
#     bash g-tests.sh <tree> <label> <test>...     -> logs/g-tests-<label>.log (appended)
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh" >/dev/null 2>&1
T=$1; label=$2; shift 2
export JULIA_DEPOT_PATH=$R/.julia-depot/agent-depots/w19:$R/.julia-depot: JULIA_PKG_OFFLINE=true
L=$H/logs/g-tests-$label.log
tests=$(printf '"%s",' "$@")
{ echo "# W-19 g-tests $label | $T $(git -C $R/$T log -1 --format=%h) | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg) | $*"
  nice -n 10 $R/$T/julia --startup-file=no -e "Base.runtests([$tests]; ncores=1)" 2>&1 | grep -vE "^\s*$|^  (LD_LIBRARY_PATH|JULIA_DEPOT_PATH) =" | sed -E 's/setenv[(](.*),[[].*[]][)]/setenv(\1, [environment])/' | cut -c1-600
  echo "-- rc ${PIPESTATUS[0]} | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg)"
} >> $L 2>&1
