# W-143c's shell setup: the workspace's env.sh, then a depot of this item's own in front of the shared one
# (compiled caches go there; packages come from the shared one). No Pkg operation is run.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/env.sh"
mkdir -p $TW_ROOT/.julia-depot/agent-depots/w143
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w143:$TW_ROOT/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_GC_AUTO=false
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT JULIA_LOAD_PATH
export W143C=$TW_ROOT/experiments/implementation/w143c
export JN=$TW_ROOT/julia-next/julia
export CSVFILE=$TW_ROOT/experiments/interfaces/App/data/sample.csv
ulimit -c 0
