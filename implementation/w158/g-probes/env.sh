# W-158, the check's reading of optimized code: `source experiments/implementation/w158/g-probes/env.sh` from anywhere.
# The workspace's env.sh, then the depot `agent-depots/w158g` stacked before the shared one; no Pkg operation.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/env.sh"
mkdir -p $TW_ROOT/.julia-depot/agent-depots/w158g
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w158g:$TW_ROOT/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
export W158=$TW_ROOT/experiments/implementation/w158 JN=$TW_ROOT/julia-next/julia LIBG=$TW_ROOT/wt/w158g-tw
export ENVG=$W158/g-probes/env_demo_g ENVTG=$W158/g-probes/env_tables_g
