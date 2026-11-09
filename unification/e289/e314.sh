#!/bin/bash
# E-314 and E-315 on the build in julia-unified (b61e326170: C-36, F-24's cache, Core.attributed_call's table) with
# TraitWorld's folded field type of a Dynamic:
#   1. the environments precompiled again;
#   2. the gates (m*, n*, f*);
#   3. TraitWorld's tests;
#   4. E-315: DataFrames' test files (tables.jl, data.jl, dataframe.jl, sort.jl) in Pkg.test's sandbox;
#   5. E-314: NetworkDynamics' step d timed and profiled (ndport/scripts/e313_probe.jl), the workload (a warm-up, a run).
# Logs: logs/e314-*.log here, NetworkDynamics' in ndport/logs/unified.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
L=${1:?label}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
pc() { nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' 2>&1 | grep -v "WARNING: method _read\|^│\|^┌\|^└" | tail -2; }

step "1. precompile"
pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
(unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks")
pc "$R/ndport/env_unified_r5"

step "2. gates"
bash "$R/experiments/unification/gates/run_all.sh" julia-unified 'm[12]_*' > "$H/logs/e314-gates-m-$L.log" 2>&1; tail -1 "$H/logs/e314-gates-m-$L.log"
bash "$R/experiments/unification/gates/run_all.sh" julia-unified '[nf]*' > "$H/logs/e314-gates-nf-$L.log" 2>&1; tail -1 "$H/logs/e314-gates-nf-$L.log"; grep -A6 '^FAIL' "$H/logs/e314-gates-nf-$L.log" | head -20

step "3. TraitWorld's tests"
(cd "$R/TraitWorld-unified" && nice -n 10 "$U" --startup-file=no --project=. test/runtests.jl > "$H/logs/e314-traitworld-$L.log" 2>&1; echo "traitworld exit $?")
grep -E 'Test Summary|Fail|Error' "$H/logs/e314-traitworld-$L.log" | head -8

step "4. E-315: DataFrames' test files"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks "$R/experiments/unification/c36/df_subset.jl" tables.jl data.jl dataframe.jl sort.jl > "$H/logs/e315-df-$L.log" 2>&1; echo "df exit $?")
grep -E '^== |Test Summary|Error During|Test Failed|tests passed|did not pass|FILE ' "$H/logs/e315-df-$L.log" | head -30

step "5. E-314: NetworkDynamics"
(cd "$R/ndport" && export OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 NDW_API=ports NDW_STACK=ports NDW_PASSES=again && \
    nice -n 10 "$U" --startup-file=no --threads=1 --project=env_unified_r5 scripts/e313_probe.jl > "logs/unified/e314-probe-$L.log" 2>&1)
grep -E '^P step_d|^T again d' "$R/ndport/logs/unified/e314-probe-$L.log"
(cd "$R/ndport" && bash scripts/u_workload.sh "e314-$L-warmup" 1 && bash scripts/u_workload.sh "e314-$L" 1)
grep -E '^T (again|changed) d |^W total' "$R/ndport/logs/unified/e314-$L-1.log"
step "done"
