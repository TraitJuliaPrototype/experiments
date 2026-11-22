# W-143d's shell setup: the workspace's env.sh, then a depot of this item's own per Julia tree in front of the
# shared one (compiled caches go there; packages come from the shared one). No Pkg operation is run.
#   TREE=<julia tree relative to the workspace> (default julia-next): the binary; the depot agent-depots/w143d/<tree's last path part>
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/env.sh"
TREE=${TREE:-julia-next}
export W143D=$TW_ROOT/experiments/implementation/w143d
export JN=$TW_ROOT/$TREE/julia
export W143D_DEPOT=$TW_ROOT/.julia-depot/agent-depots/w143d/$(basename $TREE)
mkdir -p $W143D_DEPOT
export JULIA_DEPOT_PATH=$W143D_DEPOT:$TW_ROOT/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_GC_AUTO=false
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT JULIA_LOAD_PATH
export CSVFILE=$TW_ROOT/experiments/interfaces/App/data/sample.csv
ulimit -c 0
