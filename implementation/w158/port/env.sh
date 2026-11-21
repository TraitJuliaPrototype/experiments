# W-158, the port's part: `source experiments/implementation/w158/port/env.sh`. The workspace's env.sh, then a
# depot of this part's own stacked before the shared one (compiled caches go there; packages come from the shared
# depot), julia-next and the build's project (../../w156/env_demo).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/env.sh"
mkdir -p $TW_ROOT/.julia-depot/agent-depots/w158p
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w158p:$TW_ROOT/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
export PORT=$TW_ROOT/experiments/implementation/w158/port W166=$TW_ROOT/experiments/implementation/w166
export W135=$TW_ROOT/experiments/implementation/w135 W156=$TW_ROOT/experiments/implementation/w156
export JN=$TW_ROOT/julia-next/julia ENVD=$TW_ROOT/experiments/implementation/w156/env_demo
rev() { git -C "$TW_ROOT/$1" log -1 --format=%h; }
