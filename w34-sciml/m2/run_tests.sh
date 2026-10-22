#!/bin/bash
# E-158: TDE's test suite (Pkg.test) on the checkout as it stands.  usage: ./run_tests.sh <label>
set -u
cd "$(dirname "$0")"
label=${1:?label}
TDE=/home/hellmann/Repos/julia-trait-bound/TraitDifferentialEquations
log=logs/tests-$label.log
{
  echo "# E-158 tests $label  TDE $(git -C $TDE rev-parse --short HEAD)$(git -C $TDE diff --quiet || echo +changes) ($(git -C $TDE branch --show-current))  TraitWorld $(git -C $TDE/../TraitWorld rev-parse --short HEAD)"
  echo "# load at start: $(cut -d' ' -f1-3 /proc/loadavg)"
} > $log
timeout 1500 ./jl.sh --project=$TDE -e 'using Pkg; Pkg.test()' >> $log 2>&1
echo "exit $?" >> $log
echo "# load at end: $(cut -d' ' -f1-3 /proc/loadavg)" >> $log
grep -E 'Test Summary|tests passed|Error|Fail|exit' $log | tail -15
