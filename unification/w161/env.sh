# W-161's shell (the merge of next-s3 into next; open issue 204; D-4; D-2):
# `source experiments/unification/w161/env.sh`. The workspace's env.sh, then a depot of this agent's own
# stacked before the shared one: compiled caches go there, packages come from the shared depot.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/env.sh"
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w161:$TW_ROOT/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
export W161=$TW_ROOT/experiments/unification/w161
export JN=$TW_ROOT/julia-next/julia JU=$TW_ROOT/julia-unified/julia
export CSVFILE=$TW_ROOT/experiments/interfaces/App/data/sample.csv
export LOADS="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"
mkdir -p $TW_ROOT/.julia-depot/agent-depots/w161
