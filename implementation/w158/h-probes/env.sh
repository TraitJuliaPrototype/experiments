# W-158, the check's verdict and the optimizer (open issue 251): `source experiments/implementation/w158/h-probes/env.sh`
# from anywhere. The workspace's env.sh, then the depot `agent-depots/w158h` stacked before the shared one; no Pkg
# operation. The environments `g-probes/env_demo_g`, `env_tables_g` point at the library's worktree `wt/w158g-tw`
# (branch `w158h`).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/env.sh"
mkdir -p $TW_ROOT/.julia-depot/agent-depots/w158h
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w158h:$TW_ROOT/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
export W158=$TW_ROOT/experiments/implementation/w158 JN=$TW_ROOT/julia-next/julia LIBG=$TW_ROOT/wt/w158g-tw
export ENVG=$W158/g-probes/env_demo_g ENVTG=$W158/g-probes/env_tables_g
