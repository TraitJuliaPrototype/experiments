# W-157's shell setup (stage 5: Base's surface by the census): the workspace's env.sh, then a depot of this
# agent's own in front of the shared one (compiled caches go there; packages come from the shared one).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/env.sh"
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w157:$TW_ROOT/.julia-depot
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
export W157=$TW_ROOT/experiments/implementation/w157
export JS=$TW_ROOT/julia-s3/julia JU=$TW_ROOT/julia-unified/julia
export CSVFILE=$TW_ROOT/experiments/interfaces/App/data/sample.csv
export LOADS="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"
