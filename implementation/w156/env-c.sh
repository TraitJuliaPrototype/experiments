# W-156's third part: `source experiments/implementation/w156/env-c.sh`. The workspace's env.sh, then a depot
# of this part's own stacked before the shared one (its images are built by the w156 Julia tree, apart from the
# second part's), and JW, the w156 tree's binary.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/env.sh"
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w156c:$TW_ROOT/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
export W156=$TW_ROOT/experiments/implementation/w156
export JW=$TW_ROOT/wt/w156-julia/julia
export JN=$TW_ROOT/julia-next/julia
mkdir -p $TW_ROOT/.julia-depot/agent-depots/w156c
