#!/bin/bash
# E-157 check 1: TDE's scripted session (scripts/session.jl trait), its RESULT lines kept.
# usage: ./run_session.sh <label> [chunk]    e.g. main-1, w34-1 (the TDE checkout as it stands)
#   chunk: the session with every Rodas5() replaced by Rodas5(chunk_size = 0) (session_chunk.jl, made
#   here by sed from TDE's scripts/session.jl): the dual chunk picked per problem at Rodas5's init.
# Product setting, strict mode off, one job at a time through the shared lock, niced.
set -u
cd "$(dirname "$0")"
label=${1:?label}
TDE=/home/hellmann/Repos/julia-trait-bound/TraitDifferentialEquations
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
export JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_PKG_OFFLINE=true JULIA_TW_STRICT=0
export JULIA_DEPOT_PATH=/tmp/claude-1000/depot-w34:$HOME/.julia:
variant=${2:-}
script=scripts/session.jl
if [ "$variant" = chunk ]; then
  sed 's/Rodas5()/Rodas5(chunk_size = 0)/g' $TDE/scripts/session.jl > session_chunk.jl
  script=$PWD/session_chunk.jl
fi
log=logs/session-$label.log
{
  echo "# E-157 session $label ($script)  TDE $(git -C $TDE rev-parse --short HEAD)$(git -C $TDE diff --quiet || echo +changes) ($(git -C $TDE branch --show-current))  TraitWorld $(git -C $TDE/../TraitWorld rev-parse --short HEAD)"
  echo "# load at start: $(cut -d' ' -f1-3 /proc/loadavg)"
} > $log
cd $TDE
JULIA_LOAD_PATH="scripts/env:@stdlib" timeout 900 flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no $script trait >> $OLDPWD/$log 2>&1
echo "exit $?" >> $OLDPWD/$log
echo "# load at end: $(cut -d' ' -f1-3 /proc/loadavg)" >> $OLDPWD/$log
cd $OLDPWD
grep -c '^RESULT' $log; grep '^SESSION' $log
