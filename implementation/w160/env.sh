# W-160's shell: `source experiments/implementation/w160/env.sh`. The workspace's env.sh, then a depot of
# W-160's own stacked before the shared one: compiled caches are written here, so agents side by side
# never evict each other's caches; packages come from the shared depot.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/env.sh"
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w160:$TW_ROOT/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
export W160=$TW_ROOT/experiments/implementation/w160
export JN=$TW_ROOT/julia-next/julia JU=$TW_ROOT/julia-unified/julia
mkdir -p $TW_ROOT/.julia-depot/agent-depots/w160
