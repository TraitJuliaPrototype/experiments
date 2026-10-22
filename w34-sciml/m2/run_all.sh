#!/bin/bash
# E-158: every check once, serially, each in a fresh session (jl.sh: the shared lock, two cores,
# nice 19, one thread). usage: ./run_all.sh <run>   (run1, run2)   Logs: logs/<check>-<run>.log
# Product setting, strict mode off, TDE's load order (TDE, its example packages, the control
# PlainODE, then the script). The TDE checkout as it stands (branch w34).
set -u
cd "$(dirname "$0")"
run=${1:?run}
./run_session.sh w34-$run                      # TDE's RESULT lines unchanged (the session's new callback type)
for c in check1_events check2_codeinstances check3_typed_p "check5_steps" "check5_steps hot"; do
  set -- $c
  log=logs/${1%%_*}${2:+-$2}-$run.log
  echo "--- $c (load $(cut -d' ' -f1-3 /proc/loadavg))"
  timeout 900 ./jl.sh --project=. $1.jl ${2:-} > $log 2>&1
  echo "exit $?" >> $log
  grep -E '^RESULT|^checks:' $log; tail -1 $log
done
