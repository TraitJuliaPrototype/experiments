#!/bin/bash
# E-261: the two sessions (or only the second: run.sh g2all), one Julia process each, on the patched build (julia-1.13), product setting.
R=${TW_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
cd "$R"; source env.sh >/dev/null
D=experiments/unification/s0a
export S0A_OUT=$R/$D/out JULIA_PKG_OFFLINE=true
J=julia-1.13/julia
if [ "${1:-all}" != g2all ]; then
echo "== forks $(date +%T) load $(cut -d' ' -f1 /proc/loadavg)"
nice -n 10 $J --startup-file=no --project=forks/env_forks $D/s0a.jl forks CSV DataFrames Statistics Dates
fi
echo "== g2all $(date +%T) load $(cut -d' ' -f1 /proc/loadavg)"
JULIA_LOAD_PATH="TraitMakie/scripts/env:TraitDifferentialEquations/scripts/env:TraitReport/env_loads:@stdlib" \
  nice -n 10 $J --startup-file=no $D/s0a.jl g2all TraitDifferentialEquations TraitMakie work:$R/$D/g2work.jl \
  CSV DataFrames CairoMakie OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays
echo "== done $(date +%T)"
