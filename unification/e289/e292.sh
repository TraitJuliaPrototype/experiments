#!/bin/bash
# E-292 (W-123's gate): after a build of stage 1's fixes, one job at a time:
#   1. the environments precompiled again (a rebuilt system image makes every package image stale);
#   2. the battery (label $1, default w123b);
#   3. the ports' checks: the forks' session digests, TraitReport's (t)/(pt) check;
#   4. E-289's sessions on the new build (labels *-w123): the goal's task, the forks' session, setting D,
#      TraitReport (t); then the loads profiled by class (load_profile.jl).
# PYENV must name the Python of E-284. Logs: logs/e292-*.log here, the battery's in ../stack/logs/.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
L=${1:-w123b}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
pc() { nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' 2>&1 | grep -v "WARNING: method _read\|^│\|^┌\|^└" | tail -3; }

step "1. precompile"
pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
pc "$R/TraitReport-unified/env_t"; pc "$R/TraitReport-unified/env_pt"; pc "$R/TraitReport-unified/env_fu"
pc "$H/env_d_unified"
(unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks"; pc "$R/forks-unified/env_upstream")

step "2. battery $L"
bash "$R/experiments/unification/stack/battery.sh" julia-unified "$L"

step "3. checks"
(cd "$R/forks-unified" && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
(cd "$R/TraitReport-unified" && JULIA=$U LOCK=$H/.lock bash scripts/check.sh 2>&1 | tail -5)

step "4. sessions"
for p in f-unified-w123 forks-unified-w123 d-unified-w123 t-unified-w123; do bash "$H/run.sh" "$p" 3 > /dev/null 2>&1; done
step "4b. profiles"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && W121_CALLBACKS_LAST=1 W121_PROFILE=1 nice -n 10 "$U" --startup-file=no --project=env_forks \
    "$R/experiments/unification/w121/load_profile.jl" TraitWorld Tables CSV DataFrames 2>&1 | grep "^P ") > "$H/logs/e292-profile-forks.log"
(cd "$R/TraitReport-unified" && W121_CALLBACKS_LAST=1 W121_PROFILE=1 nice -n 10 "$U" --startup-file=no --project=env_t \
    "$R/experiments/unification/w121/load_profile.jl" TraitWorld TraitCSV TraitTables TraitMakie 2>&1 | grep "^P ") > "$H/logs/e292-profile-t.log"
step "done"
