#!/bin/bash
# E-317: the goal's task and the forks' steps, profiled once each for the member checks (L-55).
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
U=$R/julia-unified/julia; L=${1:?label}
export JULIA_PKG_OFFLINE=true
mkdir -p "$H/logs"
(cd "$R/TraitReport-unified" && SCRIPT=$R/TraitReport-unified/scripts/report_forks.jl CSVF=$R/experiments/interfaces/App/data/sample.csv PNGF=$(mktemp -d)/goal.png \
    nice -n 10 "$U" --startup-file=no --project=env_fu "$H/checks_profile.jl" > "$H/logs/goal-$L.log" 2>&1; echo "goal exit $?")
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && SCRIPT=$R/experiments/unification/w121/steps_traced.jl CSVF=x PNGF=x DATA=$R/forks-unified/data \
    nice -n 10 "$U" --startup-file=no --project=env_forks "$H/checks_profile.jl" > "$H/logs/forks-$L.log" 2>&1; echo "forks exit $?")
for f in goal forks; do echo "== $f"; grep -E '^whole|%|members checked' "$H/logs/$f-$L.log"; done
