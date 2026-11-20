# W-158's shell: `source experiments/implementation/w158/env.sh`. The workspace's env.sh, then a depot of this
# work's own stacked before the shared one: compiled caches go there, packages come from the shared depot.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/env.sh"
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w158:$TW_ROOT/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
export W158=$TW_ROOT/experiments/implementation/w158 W166=$TW_ROOT/experiments/implementation/w166
export JN=$TW_ROOT/julia-next/julia
mkdir -p $TW_ROOT/.julia-depot/agent-depots/w158
export W156=$TW_ROOT/experiments/implementation/w156
