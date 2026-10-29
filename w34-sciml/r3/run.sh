#!/bin/bash
# E-242 (W-32 R3-R5, the TDE items left for NetworkDynamics): TDE's checks, each in a fresh process, through the shared lock, niced.
# usage: ./run.sh <run>     Logs: logs/{session,tests}-<run>.log
#   1. TDE's session (scripts/session.jl trait): RESULT lines against experiments/w81/x1/session-x1-one-function.log
#   2. TDE's Pkg.test() (the product setting, stock image)
# Product setting (no -J facts sys.so), strict mode off, the TDE checkout as it stands (branch w34).
set -u
cd "$(dirname "$0")"; H=$PWD; R=$(cd ../../.. && pwd)
run=${1:?run}
J=$R/julia-1.13/julia
export JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_PKG_OFFLINE=true JULIA_TW_STRICT=0
jl() { $R/experiments/tools/jl --name r3-tde timeout -s KILL 1800 "$@"; }
mkdir -p logs
( cd $R/TraitDifferentialEquations && echo "# load $(cut -d' ' -f1-3 /proc/loadavg) TDE $(git rev-parse --short HEAD)$([ -z "$(git status --porcelain --untracked-files=no)" ] || echo '*') TraitWorld $(git -C $R/TraitWorld rev-parse --short HEAD) julia-1.13 $(git -C $R/julia-1.13 rev-parse --short HEAD)"
  JULIA_LOAD_PATH="scripts/env:@stdlib" jl $J --startup-file=no scripts/session.jl trait 2>&1; echo "exit $?" ) > logs/session-$run.log
diff <(grep '^RESULT' $R/experiments/w81/x1/session-x1-one-function.log) <(grep '^RESULT' logs/session-$run.log) > /dev/null &&
  echo "check 1: $(grep -c '^RESULT' logs/session-$run.log) RESULT lines identical to session-x1-one-function.log" ||
  echo "check 1: RESULT lines DIFFER"
( cd $R/TraitDifferentialEquations && jl $J --startup-file=no --project=. -e 'using Pkg; Pkg.test()' 2>&1; echo "exit $?" ) > logs/tests-$run.log
echo "check 2: $(grep -E 'tests passed|tests failed|exit' logs/tests-$run.log | tr '\n' ' ')"
