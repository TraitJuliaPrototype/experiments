# W-163's shell: `source experiments/implementation/w163/env.sh`. The workspace's env.sh, then a depot of
# this agent's own stacked before the shared one: the caches the w163 binaries compile go there.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/env.sh"
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w163:$TW_ROOT/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
export W163=$TW_ROOT/experiments/implementation/w163
export JW=$TW_ROOT/wt/w163-julia/julia JN=$TW_ROOT/julia-next/julia
mkdir -p $TW_ROOT/.julia-depot/agent-depots/w163
