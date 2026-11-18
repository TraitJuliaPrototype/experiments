# W-155's shell setup: the workspace's env.sh, then a depot of this agent's own in front of the shared one
# (compiled caches go there, so the shared depot's caches are never evicted; packages come from the shared one).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/env.sh"
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w155:$TW_ROOT/.julia-depot
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
export W155=$TW_ROOT/experiments/implementation/w155
export JN=$TW_ROOT/julia-next/julia JU=$TW_ROOT/julia-unified/julia
export CSVFILE=$TW_ROOT/experiments/interfaces/App/data/sample.csv
export LOADS="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"
