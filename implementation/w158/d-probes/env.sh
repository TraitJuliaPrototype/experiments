# W-158, the library's pieces continued: `source experiments/implementation/w158/d-probes/env.sh` from anywhere.
# The workspace's env.sh, then the depot `agent-depots/w158b` stacked before the shared one; no Pkg operation.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/env.sh"
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w158b:$TW_ROOT/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
export W158=$TW_ROOT/experiments/implementation/w158 JN=$TW_ROOT/julia-next/julia LIBD=$TW_ROOT/wt/w158b-tw
