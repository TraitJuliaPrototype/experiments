#!/bin/bash
# W-160: the ports' suites on `julia-next`: the ODE port's (`Pkg.test()` in its tree) and NetworkDynamics' test
# subset (ndport's `scripts/r3_nd_tests.jl`, two threads, env `nd/env_test_head`). One job at a time, niced.
# Logs: logs/<label>-tde.log, logs/<label>-nd.log; a line each in logs/<label>-summary.log.
#     bash ports.sh <label>
set -u
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"
L=$1; LOG=$H/logs; S=$LOG/$L-summary.log
rev() { git -C "$1" log -1 --format=%h; }
echo "# $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-next $(rev $TW_ROOT/julia-next) | TraitWorld $(rev $TW_ROOT/TraitWorld-unified) TDE $(rev $TW_ROOT/TraitDifferentialEquations-unified) ND $(rev $TW_ROOT/ndport/pkgs/NetworkDynamics-unified)" | tee -a "$S"
s=$(date +%s)
(cd $TW_ROOT/TraitDifferentialEquations-unified && nice -n 10 $JN --startup-file=no --project=. -e 'using Pkg; Pkg.test()') > $LOG/$L-tde.log 2>&1; rc=$?
echo "tde | exit $rc | $(( $(date +%s) - s )) s | $(grep -c '^Test Summary' $LOG/$L-tde.log) testsets | $(grep -E 'tests passed|Some tests did not pass' $LOG/$L-tde.log | tail -1)" | tee -a "$S"
s=$(date +%s)
(cd $TW_ROOT/ndport && nice -n 10 $JN -t 2 --startup-file=no --project=$H/nd/env_test_head scripts/r3_nd_tests.jl) > $LOG/$L-nd.log 2>&1; rc=$?
echo "nd | exit $rc | $(( $(date +%s) - s )) s | $(grep '^TEST' $LOG/$L-nd.log | tr '\n' ';' | cut -c1-600)" | tee -a "$S"
