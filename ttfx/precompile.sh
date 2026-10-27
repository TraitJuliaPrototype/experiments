#!/bin/bash
# E-168: precompile the settings' environments into their depots, one job at a time, alone;
# logs/precompile-<setting>.log.   bash precompile.sh "S U C D A"
cd "$(dirname "$0")"; H=$PWD; R=$(cd ../.. && pwd)
export JULIA_PKG_GC_AUTO=false JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=${TASKS:-2}
JP=$R/julia-1.13/julia; JS=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia
pc() { local s=$1 j=$2 env=$3 dep=$4; shift 4
  ( [ -n "$dep" ] && export JULIA_DEPOT_PATH=$dep || unset JULIA_DEPOT_PATH
    flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 3600 $j "$@" --startup-file=no --project=$env -e 'using Pkg; t = @elapsed Pkg.precompile(); println("precompile s=", round(t; digits = 1))' ) > logs/precompile-$s.log 2>&1
  echo "$s: $(grep -E 'precompile s=|ERROR' logs/precompile-$s.log | tail -1)"; }
mkdir -p logs
for s in ${1:-S U C D}; do case $s in
  S) pc S $JS env_up "$H/depot-S:$HOME/.julia:" ;;
  U) pc U $JP env_up "" ;;
  C) pc C $JP env_core "$H/depot-C:$HOME/.julia:" ;;
  D) pc D $JP env_d "" ;;
  A) pc A $JP env_up "$H/depot-A:$HOME/.julia:" -J $R/julia-1.13/usr/lib/julia/facts/sys.so ;;
esac; done
