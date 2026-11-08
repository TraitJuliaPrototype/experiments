#!/bin/bash
# E-298 (W-128: build B2 completed, ef93ff7844, with TDE's port fix):
#   1. the environments precompiled again (a rebuilt system image makes every package image stale);
#   2. TraitDifferentialEquations' suite (C-54's three checks marked broken);
#   3. E-289's sessions (labels *-$1): the goal's task, the forks' session, setting D, TraitReport (t);
#   4. the goal's task again with TraitWorld's src at e6eaa85 (before open issue 158 (a)'s library half),
#      label $1-tw0, then src restored to its head and env_fu precompiled again;
#   5. the battery (label $1) and the ports' checks.
# PYENV must name the Python of E-284. Logs: logs/e298-*.log here, the battery's in ../stack/logs/.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
L=${1:-w128c}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
pc() { nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' 2>&1 | grep -v "WARNING: method _read\|^│\|^┌\|^└" | tail -3; }

step "1. precompile"
pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
pc "$R/TraitReport-unified/env_t"; pc "$R/TraitReport-unified/env_pt"; pc "$R/TraitReport-unified/env_fu"
pc "$R/TraitDifferentialEquations-unified"
(cd "$R/experiments/ttfx" && nice -n 10 "$U" --startup-file=no --project="$H/env_d_unified" -e "using TraitDifferentialEquations, TraitMakie, TraitWorld" 2>&1 | grep -v "WARNING: method _read" | tail -2)
(unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks"; pc "$R/forks-unified/env_upstream")

step "2. TraitDifferentialEquations' suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e298-tde-test.log" 2>&1; echo "tde exit $?")
grep -E "Test Summary|Unexpected Pass|Broken|Error|Fail|tests passed" "$H/logs/e298-tde-test.log" | head -12 | cut -c1-200

step "3. sessions"
for p in f-unified-$L forks-unified-$L d-unified-$L t-unified-$L; do bash "$H/run.sh" "$p" 3 > /dev/null 2>&1; done

step "4. the goal's task with TraitWorld's src at e6eaa85"
TW=$R/TraitWorld-unified
git -C "$TW" checkout -q e6eaa85 -- src
pc "$R/TraitReport-unified/env_fu"
bash "$H/run.sh" "f-unified-$L-tw0" 3 > /dev/null 2>&1
git -C "$TW" checkout -q HEAD -- src
git -C "$TW" status --short src
pc "$R/TraitReport-unified/env_fu"

step "5. battery $L"
bash "$R/experiments/unification/stack/battery.sh" julia-unified "$L"
step "5b. checks"
(cd "$R/forks-unified" && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
(cd "$R/TraitReport-unified" && JULIA=$U LOCK=$H/.lock bash scripts/check.sh 2>&1 | tail -5)
step "done"
