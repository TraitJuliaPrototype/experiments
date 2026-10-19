#!/bin/bash
R=/home/hellmann/Repos/julia-trait-bound; J=$R/julia-1.13/julia; L=/tmp/claude-1000/julia-review.lock
cd $R/forks; export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
flock $L nice -n 10 timeout 5400 $J --startup-file=no --project=env_forks -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -2
JULIA_LOCK=$L bash scripts/measure_session.sh 3 "fk-patched" > /tmp/claude-1000/demos/m/forks-s15.log 2>&1
python3 scripts/summarize.py < /tmp/claude-1000/demos/m/forks-s15.log | grep -E "imports|read|3_|session|wall"
JULIA_LOCK=$L bash scripts/check_session.sh 2>&1 | tail -4
