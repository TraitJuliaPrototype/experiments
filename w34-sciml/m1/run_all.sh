#!/bin/bash
# E-157: every check once, serially, each in a fresh session, through the shared lock, niced.
# usage: ./run_all.sh <run>     (e.g. run1, run2)    Logs: logs/<check>-<run>.log
# Product setting (no -J facts sys.so), strict mode off, TDE's load order (TDE, its example
# packages, then the script). The TDE checkout as it stands (branch w34).
set -u
cd "$(dirname "$0")"
run=${1:?run}
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
export JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_PKG_OFFLINE=true JULIA_TW_STRICT=0
export JULIA_DEPOT_PATH=/tmp/claude-1000/depot-w34:$HOME/.julia:
./run_session.sh w34-$run                      # check 1: the session's RESULT lines
./run_session.sh w34-chunk-$run chunk          # check 1: the same with the chunk picked at init
for c in check2_percall check3_steps check4_codeinstances check5_wrong_result check6_trajectory; do
  log=logs/${c%%_*}-$run.log
  echo "--- $c (load $(cut -d' ' -f1-3 /proc/loadavg))"
  timeout 900 flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no --project=. $c.jl > $log 2>&1
  echo "exit $?" >> $log
  tail -1 $log
done
for v in w34-$run w34-chunk-$run; do
  diff <(grep '^RESULT' logs/session-main-1.log) <(grep '^RESULT' logs/session-$v.log) > /dev/null &&
    echo "check 1: $v RESULT lines identical to main's" || echo "check 1: $v RESULT lines DIFFER from main's"
done
