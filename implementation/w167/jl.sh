#!/bin/bash
# W-167: Julia as this work runs it. env.sh; the head's Julia (julia-next, read only); a depot of its own first, then
# the round's setting H read only (its images of packages that do not depend on the library), then the shared depot;
# offline; niced; one thread.        jl.sh <julia args...>
R=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
source "$R/env.sh" >/dev/null 2>&1
mkdir -p "$R/.julia-depot/agent-depots/w167"
export JULIA_DEPOT_PATH="${W167_DEPOT:-$R/.julia-depot/agent-depots/w167}:$R/.julia-depot/agent-depots/w159/H:$R/.julia-depot:"
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_GC_AUTO=false
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT JULIA_LOAD_PATH
exec nice -n 10 "${W167_JULIA:-$R/julia-next/julia}" --startup-file=no --history-file=no -t 1 "$@"
