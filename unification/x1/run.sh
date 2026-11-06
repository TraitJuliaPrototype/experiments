#!/bin/bash
# E-265 (X1): one session (forks | g2all) in every mode, one Julia job per mode through experiments/tools/jl,
# product setting. Usage: run.sh <run> <session> [modes]   (out/<run>-<session>-<mode>.*, logs/<run>-<session>.log)
set -eu
R=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$R"; source env.sh >/dev/null
export JL_CORES=8 JL_SLOTS=2   # two jobs of 4 cores side by side while the machine is nearly empty
D=experiments/unification/x1; S0=experiments/unification/s0a
RUN=$1; SES=$2; MODES=${3:-"control slot noslot upper-slot upper-noslot"}
export X1_OUT=$R/$D/out X1_DATA=$R/$D/data JULIA_PKG_OFFLINE=true
J=$R/julia-1.13/julia
{
echo "# $(date -Is) julia-1.13 $(git -C julia-1.13 rev-parse --short HEAD), TraitWorld $(git -C TraitWorld rev-parse --short HEAD), forks $(git -C forks rev-parse --short HEAD), TraitMakie $(git -C TraitMakie rev-parse --short HEAD), TDE $(git -C TraitDifferentialEquations rev-parse --short HEAD), TraitReport $(git -C TraitReport rev-parse --short HEAD)"
for M in $MODES; do
  echo "== $SES $M $(date +%T) load $(cut -d' ' -f1-3 /proc/loadavg)"
  case $SES in
    forks) X1_MODE=$M X1_WORK=$R/$D/forkswork.jl JULIA_PROJECT=$R/forks/env_forks \
             experiments/tools/jl --name x1 $J --startup-file=no $D/x1.jl $RUN-forks-$M CSV DataFrames Statistics Dates ;;
    g2all) X1_MODE=$M X1_WORK=$R/$D/g2call.jl \
             JULIA_LOAD_PATH="$R/TraitMakie/scripts/env:$R/TraitDifferentialEquations/scripts/env:$R/TraitReport/env_loads:@stdlib" \
             experiments/tools/jl --name x1 $J --startup-file=no $D/x1.jl $RUN-g2all-$M TraitDifferentialEquations TraitMakie work:$R/$S0/g2work.jl \
             CSV DataFrames CairoMakie OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays ;;
  esac
done
echo "== done $(date +%T) load $(cut -d' ' -f1-3 /proc/loadavg)"
} 2>&1 | tee $D/logs/$RUN-$SES.log
