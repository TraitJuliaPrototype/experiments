# W-158, "A name never defined; a trait's operation and its members": `source o-probes/env.sh`. This directory's
# env.sh, then this part's own depot before the shared one (compiled caches there; packages from the shared depot).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"
mkdir -p $TW_ROOT/.julia-depot/agent-depots/w158n2
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w158n2:$TW_ROOT/.julia-depot: JULIA_PKG_OFFLINE=true
export LIBO=$TW_ROOT/wt/w158g-tw
