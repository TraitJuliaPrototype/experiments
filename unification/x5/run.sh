#!/bin/bash
# E-266 (X5): one Julia job per image (TraitWorld, TraitDifferentialEquations, TraitMakie) through
# experiments/tools/jl, product setting. Usage: run.sh <run>   (out/<run>-<pkg>.*, logs/<run>.log)
set -eu
R=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$R"; source env.sh >/dev/null
export JL_CORES=8 JL_SLOTS=2   # two jobs of 4 cores side by side while the machine is nearly empty (X1 and X5)
D=experiments/unification/x5
RUN=${1:-run1}
export X5_OUT=$R/$D/out JULIA_PKG_OFFLINE=true
export JULIA_LOAD_PATH="$R/TraitMakie/scripts/env:$R/TraitDifferentialEquations/scripts/env:@stdlib"
J=$R/julia-1.13/julia
{
echo "# $(date -Is) julia-1.13 $(git -C julia-1.13 rev-parse --short HEAD), TraitWorld $(git -C TraitWorld rev-parse --short HEAD), TDE $(git -C TraitDifferentialEquations rev-parse --short HEAD), TraitMakie $(git -C TraitMakie rev-parse --short HEAD)"
for P in TraitWorld TraitDifferentialEquations TraitMakie; do
  echo "== $P $(date +%T) load $(cut -d' ' -f1-3 /proc/loadavg)"
  experiments/tools/jl --name x5 $J --startup-file=no $D/x5.jl $RUN-$P $P
done
echo "== done $(date +%T) load $(cut -d' ' -f1-3 /proc/loadavg)"
} 2>&1 | tee $D/logs/$RUN.log
