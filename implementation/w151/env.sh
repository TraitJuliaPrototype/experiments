# W-151's shell: `source experiments/implementation/w151/env.sh` (after or instead of the workspace's env.sh).
# The workspace's env.sh, then a depot of W-151's own stacked before the shared one: compiled caches are
# read from the shared depot and written here, so the agents side by side never evict each other's caches.
source /p/projects/coen/julia-trait-bound/env.sh
export JULIA_PKG_OFFLINE=true
export W151=$TW_ROOT/experiments/implementation/w151
export JU=$TW_ROOT/julia-unified/julia
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w151:$TW_ROOT/.julia-depot:
mkdir -p $TW_ROOT/.julia-depot/agent-depots/w151
