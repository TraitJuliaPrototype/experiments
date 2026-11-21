#!/bin/bash
# The port's suite (TraitDifferentialEquations/test/runtests.jl) on julia-next, in the build's project.
#     bash suite.sh <tag>        -> logs/suite-<tag>.log (the header: the trees' commits and the load)
set -u; H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"
LOG=$H/logs/suite-$1.log
echo "# suite $1 $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-next $(rev julia-next) TraitWorld $(rev TraitWorld) TraitDifferentialEquations $(rev TraitDifferentialEquations)" > "$LOG"
(cd $TW_ROOT/TraitDifferentialEquations && nice -n 10 $JN -t 1 --startup-file=no --project=$ENVD test/runtests.jl) >> "$LOG" 2>&1
echo "exit $?; testsets $(grep -c '^Test Summary' "$LOG"); load after $(cut -d' ' -f1-3 /proc/loadavg)" | tee -a "$LOG"
grep -E "Error|Fail" "$LOG" | grep -v "^Test Summary" | head -5
