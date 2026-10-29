#!/bin/bash
# E-259 (U9): every session with the census at its end, one after the other, through the machine's slots.
#     experiments/w83/u9/run_all.sh [selftest tde makie report forks ndport]     logs: logs/<label>.log, logs/<label>-*.tsv
set -u
U=$(cd "$(dirname "$0")" && pwd); R=$(cd "$U/../../.." && pwd)
J="$R/experiments/tools/jl --name w83u9 $R/julia-1.13/julia --startup-file=no"
export JULIA_PKG_OFFLINE=true OPENBLAS_NUM_THREADS=1 JULIA_TW_VIEWCACHE=0
# caches: this slot's depot first (jl), then run_all's (julia-1.13 00dcc9994c), then ~/.julia
BASE="$HOME/.julia/agent-depots/run_all-plain:$HOME/.julia:"
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT
for s in ${@:-selftest tde makie report forks ndport}; do
  case $s in
    selftest) (cd $R && JULIA_DEPOT_PATH=$BASE $J --project=TraitWorld $U/run_selftest.jl) ;;
    tde) (cd $R/TraitDifferentialEquations && JULIA_DEPOT_PATH=$BASE JULIA_LOAD_PATH="scripts/env:@stdlib" $J $U/drive.jl tde scripts/session.jl trait) ;;
    makie) (cd $R/TraitMakie && JULIA_DEPOT_PATH=$BASE $J --project=scripts/env $U/drive.jl makie scripts/session.jl) ;;
    report) (cd $R/TraitReport && JULIA_DEPOT_PATH=$BASE $J --project=env_t $U/drive.jl report scripts/session.jl) ;;
    forks) (cd $R/forks && JULIA_DEPOT_PATH=$BASE DATA=$R/forks/data $J --project=env_forks $U/drive.jl forks scripts/session.jl) ;;
    ndport) (cd $R/ndport && JULIA_DEPOT_PATH=$R/ndport/depot-ports:$BASE JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 \
              NDW_API=ports NDW_STACK=ports NDW_PASSES=first,again,params,changed,graphtype,usertype U9_MODE=include \
              $J --threads=1 --project=env_r5 $U/drive.jl ndport scripts/workload.jl) ;;
  esac > $U/logs/$s.log 2>&1
  echo "$s rc=$? $(grep -m1 '^guards:' $U/logs/$s.log)"
done
