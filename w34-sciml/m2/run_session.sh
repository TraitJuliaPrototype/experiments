#!/bin/bash
# E-158: TDE's scripted session (scripts/session.jl trait); its RESULT lines against main's (E-157's
# logs of TDE fbb9bd8, ../m1/logs/session-main-1.log).  usage: ./run_session.sh <label>
set -u
cd "$(dirname "$0")"
label=${1:?label}
TDE=/home/hellmann/Repos/julia-trait-bound/TraitDifferentialEquations
log=$PWD/logs/session-$label.log
{
  echo "# E-158 session $label  TDE $(git -C $TDE rev-parse --short HEAD)$(git -C $TDE diff --quiet || echo +changes) ($(git -C $TDE branch --show-current))  TraitWorld $(git -C $TDE/../TraitWorld rev-parse --short HEAD)"
  echo "# load at start: $(cut -d' ' -f1-3 /proc/loadavg)"
} > $log
here=$PWD
cd $TDE
JULIA_LOAD_PATH="scripts/env:@stdlib" timeout 900 $here/jl.sh scripts/session.jl trait >> $log 2>&1
echo "exit $?" >> $log
echo "# load at end: $(cut -d' ' -f1-3 /proc/loadavg)" >> $log
cd $here
echo "RESULT lines: $(grep -c '^RESULT' $log); $(grep '^SESSION' $log)"
diff <(grep '^RESULT' ../m1/logs/session-main-1.log) <(grep '^RESULT' $log) > /dev/null &&
  echo "check: $label RESULT lines identical to main's" || echo "check: $label RESULT lines DIFFER from main's"
