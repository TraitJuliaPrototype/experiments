#!/bin/bash
# E-300 (W-123: the membership range without the walk, 89b3bcff81):
#   1. the environments precompiled again (a rebuilt system image makes every package image stale);
#   2. TraitDifferentialEquations' suite;
#   3. E-289's sessions (labels *-$1): the goal's task, the forks' session, setting D, TraitReport (t);
#   4. E-299's validation profile of the forks' DataFrames load;
#   5. the battery (label $1) and the ports' checks.
# PYENV must name the Python of E-284. Logs: logs/e300-*.log here, the battery's in ../stack/logs/.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
L=${1:-w123e}; U=$R/julia-unified/julia
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
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e300-tde-test.log" 2>&1; echo "tde exit $?")
step "3. sessions"
for p in f-unified-$L forks-unified-$L d-unified-$L t-unified-$L; do bash "$H/run.sh" "$p" 3 > /dev/null 2>&1; done

step "4. validation in the forks' DataFrames load (E-299's profile)"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks \
    "$R/experiments/unification/w121/validation_profile.jl" > "$R/experiments/unification/w121/logs/e300-forks.log" 2>&1)
head -9 "$R/experiments/unification/w121/logs/e300-forks.log"
step "5. battery $L"
bash "$R/experiments/unification/stack/battery.sh" julia-unified "$L"
step "5b. checks"
(cd "$R/forks-unified" && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
(cd "$R/TraitReport-unified" && JULIA=$U LOCK=$H/.lock bash scripts/check.sh 2>&1 | tail -5)
step "done"
