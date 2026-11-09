#!/bin/bash
# E-312: TraitWorld compiled by facts (`@compiler_options facts = true` in the library's module, branch `e312` of
# TraitWorld-unified), on E-316's build (`unified` 523214899f); E-316 is the control (labels -w316):
#   1. the environments precompiled again;
#   2. TraitWorld's tests; TraitDifferentialEquations' suite;
#   3. the census of plain CodeInstances of facts methods after a load (w121/policy_census.jl), TraitWorld's included;
#   4. E-289's sessions (labels *-$1): the goal's task, the forks' session, setting D, TraitReport (t).
# PYENV must name the Python of E-284. Logs: logs/e312-*.log here, the sessions' in logs/.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
L=${1:-w312}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
pc() { nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' 2>&1 | grep -v "WARNING: method _read\|^│\|^┌\|^└" | tail -2; }
W=$R/experiments/unification/w121
echo "TraitWorld-unified at $(git -C "$R/TraitWorld-unified" rev-parse --short HEAD) ($(git -C "$R/TraitWorld-unified" rev-parse --abbrev-ref HEAD))"

step "1. precompile"
pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
pc "$R/TraitReport-unified/env_t"; pc "$R/TraitReport-unified/env_pt"; pc "$R/TraitReport-unified/env_fu"
pc "$R/TraitDifferentialEquations-unified"
(cd "$R/experiments/ttfx" && nice -n 10 "$U" --startup-file=no --project="$H/env_d_unified" -e "using TraitDifferentialEquations, TraitMakie, TraitWorld" 2>&1 | grep -v "WARNING: method _read" | tail -2)
(unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks")

step "2. TraitWorld's tests, TraitDifferentialEquations' suite"
(cd "$R/TraitWorld-unified" && nice -n 10 "$U" --startup-file=no --project=. test/runtests.jl > "$H/logs/e312-traitworld-$L.log" 2>&1; echo "traitworld exit $?")
grep -E 'Fail|Error' "$H/logs/e312-traitworld-$L.log" | head -5
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e312-tde-test-$L.log" 2>&1; echo "tde exit $?")

step "3. census"
(cd "$R/TraitReport-unified" && nice -n 10 "$U" --startup-file=no --project=env_fu "$W/policy_census.jl" TraitWorld TraitMakie CSV DataFrames) 2>&1 | tee "$H/logs/e312-census-goal-$L.log" | grep -v '^    ' | head -20
(cd "$R/experiments/ttfx" && nice -n 10 "$U" --startup-file=no --project="$H/env_d_unified" "$W/policy_census.jl" TraitWorld TraitDifferentialEquations TraitMakie) 2>&1 | tee "$H/logs/e312-census-d-$L.log" | grep -v '^    ' | head -20

step "4. sessions"
for p in f-unified-$L forks-unified-$L d-unified-$L t-unified-$L; do bash "$H/run.sh" "$p" 3 > /dev/null 2>&1; grep -E '^(1|2|3|fk-patched [123]|[123] )|^startup' "$H/logs/$p.log" | grep -o -E 'wall [0-9.]+|total [0-9.]+' | tr '\n' ' '; echo " $p"; done
step "done"
