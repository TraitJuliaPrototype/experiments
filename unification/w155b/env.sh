# W-155b's shell setup (D-9, D-11, D-12, D-13): the workspace's env.sh, then a depot of this agent's own
# in front of the shared one (compiled caches go there; packages come from the shared one).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/env.sh"
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w155b:$TW_ROOT/.julia-depot
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
export W155B=$TW_ROOT/experiments/unification/w155b
export JS=$TW_ROOT/julia-s3/julia JU=$TW_ROOT/julia-unified/julia
export CSVFILE=$TW_ROOT/experiments/interfaces/App/data/sample.csv
export LOADS="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"
