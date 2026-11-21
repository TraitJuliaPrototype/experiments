# W-158, the nonlinear front end and NetworkDynamics' discrete callbacks (the `q-` logs): `source qenv.sh`.
# As env.sh, with this part's own depot (agent-depots/w158q) stacked before the shared one.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
mkdir -p $TW_ROOT/.julia-depot/agent-depots/w158q
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w158q:$TW_ROOT/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
