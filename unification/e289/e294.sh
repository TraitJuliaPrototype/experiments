#!/bin/bash
# E-294 (W-123, after E-292): the same steps in another order, sessions first; setting D precompiled by loading:
#   1. the environments precompiled again (a rebuilt system image makes every package image stale);
#   2. the battery (label $1, default w123b);
#   3. the ports' checks: the forks' session digests, TraitReport's (t)/(pt) check;
#   4. E-289's sessions on the new build (labels *-w123): the goal's task, the forks' session, setting D,
#      TraitReport (t); then the loads profiled by class (load_profile.jl).
# PYENV must name the Python of E-284. Logs: logs/e292-*.log here, the battery's in ../stack/logs/.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
L=${1:-w123c}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
pc() { nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' 2>&1 | grep -v "WARNING: method _read\|^│\|^┌\|^└" | tail -3; }

step "1. precompile"
pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
pc "$R/TraitReport-unified/env_t"; pc "$R/TraitReport-unified/env_pt"; pc "$R/TraitReport-unified/env_fu"
(cd "$R/experiments/ttfx" && nice -n 10 "$U" --startup-file=no --project="$H/env_d_unified" -e "using TraitDifferentialEquations, TraitMakie, TraitWorld" 2>&1 | grep -v "WARNING: method _read" | tail -2)
(unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks"; pc "$R/forks-unified/env_upstream")

step "2. the compiler's invalidations by upstream CSV and DataFrames"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_upstream "$H/compinv.jl" 2>&1 | tail -2) > "$H/logs/e294-compinv.log"; cat "$H/logs/e294-compinv.log"
step "4. sessions"
for p in f-unified-w123c forks-unified-w123c d-unified-w123c t-unified-w123c; do bash "$H/run.sh" "$p" 3 > /dev/null 2>&1; done
step "4b. profiles"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && W121_CALLBACKS_LAST=1 W121_PROFILE=1 nice -n 10 "$U" --startup-file=no --project=env_forks \
    "$R/experiments/unification/w121/load_profile.jl" TraitWorld Tables CSV DataFrames 2>&1 | grep "^P ") > "$H/logs/e294-profile-forks.log"
(cd "$R/TraitReport-unified" && W121_CALLBACKS_LAST=1 W121_PROFILE=1 nice -n 10 "$U" --startup-file=no --project=env_t \
    "$R/experiments/unification/w121/load_profile.jl" TraitWorld TraitCSV TraitTables TraitMakie 2>&1 | grep "^P ") > "$H/logs/e294-profile-t.log"
step "4c. what the forks' loads compile"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks --trace-compile="$H/logs/e294-tracecompile.jl" --trace-compile-timing \
    -e 'using TraitWorld, Tables, CSV, DataFrames' > /dev/null 2>&1)
awk '{t += $2} END {print "compiled during the loads:", NR, "signatures,", t, "ms"}' "$H/logs/e294-tracecompile.jl"; sort -k2 -rn "$H/logs/e294-tracecompile.jl" | head -5 | cut -c1-160
step "2. battery $L"
bash "$R/experiments/unification/stack/battery.sh" julia-unified "$L"

step "3. checks"
(cd "$R/forks-unified" && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
(cd "$R/TraitReport-unified" && JULIA=$U LOCK=$H/.lock bash scripts/check.sh 2>&1 | tail -5)

step "done"
