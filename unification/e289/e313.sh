#!/bin/bash
# E-313: E-311's two regressions bisected, on the build in julia-unified (for E-313: dde5f9f5dc with the Compiler at
# 24c8d4db60, branch `bisect-noc74`):
#   1. the forks' and NetworkDynamics' environments precompiled again;
#   2. the forks' REPL session (label forks-unified-$1, 3 runs);
#   3. the census of plain CodeInstances of facts methods after a load (w121/policy_census.jl);
#   4. NetworkDynamics' workload, a warm-up and a run (ndport, labels e313-$1).
# PYENV must name the Python of E-284. Logs: logs/e313-*.log here, the sessions' in logs/, NetworkDynamics' in ndport.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
L=${1:?label}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
pc() { nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' 2>&1 | grep -v "WARNING: method _read\|^│\|^┌\|^└" | tail -2; }
W=$R/experiments/unification/w121

step "1. precompile"
pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
(unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks")
pc "$R/ndport/env_unified_r5"

step "2. the forks' session"
bash "$H/run.sh" "forks-unified-$L" 3 > /dev/null 2>&1
grep -E '^fk-patched [123]' "$H/logs/forks-unified-$L.log" | grep -o -E 'read [0-9.]+|wall [0-9.]+' | tr '\n' ' '; echo

step "3. census"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks "$W/policy_census.jl" CSV DataFrames Tables) 2>&1 | tee "$H/logs/e313-census-forks-$L.log" | grep -v '^    ' | head -10

step "4. NetworkDynamics"
(cd "$R/ndport" && bash scripts/u_workload.sh "e313-$L-warmup" 1 && bash scripts/u_workload.sh "e313-$L" 1)
grep -E '^T (again|changed) d ' "$R/ndport/logs/unified/e313-$L-1.log"
step "done"
