#!/bin/bash
# E-316: the battery and the sessions on the night's build (`unified` 523214899f: C-74, C-36, F-24's cache,
# Core.attributed_call's table) with TraitWorld 6b342e9; E-312's control (TraitWorld plain):
#   1. the environments precompiled again;
#   2. TraitDifferentialEquations' suite;
#   3. E-289's sessions (labels *-$1, a warm-up and 2 runs): the goal's task, the forks' session, setting D, TraitReport (t);
#   4. the census of plain CodeInstances of facts methods after a load (w121/policy_census.jl), the goal's environment;
#   5. the battery (label $1) and the ports' checks.
# PYENV must name the Python of E-284. Logs: logs/e316-*.log here, the battery's in ../stack/logs/.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
L=${1:-w316}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
pc() { nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' 2>&1 | grep -v "WARNING: method _read\|^│\|^┌\|^└" | tail -2; }
W=$R/experiments/unification/w121

step "1. precompile"
pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
pc "$R/TraitReport-unified/env_t"; pc "$R/TraitReport-unified/env_pt"; pc "$R/TraitReport-unified/env_fu"
pc "$R/TraitDifferentialEquations-unified"
(cd "$R/experiments/ttfx" && nice -n 10 "$U" --startup-file=no --project="$H/env_d_unified" -e "using TraitDifferentialEquations, TraitMakie, TraitWorld" 2>&1 | grep -v "WARNING: method _read" | tail -2)
(unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks"; pc "$R/forks-unified/env_upstream")

step "2. TraitDifferentialEquations' suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e316-tde-test-$L.log" 2>&1; echo "tde exit $?")
grep -E 'Testing .* tests passed|Test Summary|Fail|Error' "$H/logs/e316-tde-test-$L.log" | head -5

step "3. sessions"
for p in f-unified-$L forks-unified-$L d-unified-$L t-unified-$L; do bash "$H/run.sh" "$p" 3 > /dev/null 2>&1; grep -E '^(1|2|3|fk-patched [123]|[123] )' "$H/logs/$p.log" | grep -o -E 'wall [0-9.]+|total [0-9.]+' | tr '\n' ' '; echo " $p"; done

step "4. census, the goal's environment"
(cd "$R/TraitReport-unified" && nice -n 10 "$U" --startup-file=no --project=env_fu "$W/policy_census.jl" TraitWorld TraitMakie CSV DataFrames) 2>&1 | tee "$H/logs/e316-census-goal-$L.log" | grep -v '^    ' | head -20

step "5. battery $L"
bash "$R/experiments/unification/stack/battery.sh" julia-unified "$L"
step "5b. checks"
(cd "$R/forks-unified" && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
(cd "$R/TraitReport-unified" && JULIA=$U LOCK=$H/.lock bash scripts/check.sh 2>&1 | tail -5)
step "done"
