#!/bin/bash
# E-311 (C-74: code compiled by facts kept at its policy in images) and E-310 (b) (open issue 161 (a):
# a type is its package's own only with its parameters), on the build with both:
#   1. the environments precompiled again (a rebuilt system image makes every package image stale);
#   2. the gates the two changes touch (n6_attribute, n15_image_policy, f6_reach_policy, f2_policy_flags);
#   3. the census of plain CodeInstances of facts methods after a load (w121/policy_census.jl);
#   4. TraitDifferentialEquations' suite;
#   5. E-289's sessions (labels *-$1): the goal's task, the forks' session, setting D, TraitReport (t);
#   6. the forks' steps' compiles, attributed (w121/steps_traced.jl);
#   7. NetworkDynamics' workload, the port keeping its model by `keep` (ndport, labels e310b);
#   8. the battery (label $1) and the ports' checks.
# PYENV must name the Python of E-284. Logs: logs/e311-*.log here, the battery's in ../stack/logs/.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
L=${1:-w126d}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
pc() { nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' 2>&1 | grep -v "WARNING: method _read\|^│\|^┌\|^└" | tail -3; }
W=$R/experiments/unification/w121

step "1. precompile"
pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
pc "$R/TraitReport-unified/env_t"; pc "$R/TraitReport-unified/env_pt"; pc "$R/TraitReport-unified/env_fu"
pc "$R/TraitDifferentialEquations-unified"
(cd "$R/experiments/ttfx" && nice -n 10 "$U" --startup-file=no --project="$H/env_d_unified" -e "using TraitDifferentialEquations, TraitMakie, TraitWorld" 2>&1 | grep -v "WARNING: method _read" | tail -2)
(unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks"; pc "$R/forks-unified/env_upstream")
pc "$R/ndport/env_unified_r5"

step "2. gates"
for g in n6_attribute n15_image_policy f6_reach_policy f2_policy_flags; do bash "$R/experiments/unification/gates/run_all.sh" julia-unified $g 2>&1 | head -3; done

step "3. census of facts methods' plain code"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks "$W/policy_census.jl" CSV DataFrames Tables) 2>&1 | tee "$H/logs/e311-census-forks.log" | grep -v '^    ' | head -30
(cd "$R/TraitReport-unified" && nice -n 10 "$U" --startup-file=no --project=env_fu "$W/policy_census.jl" TraitWorld TraitMakie CSV DataFrames) 2>&1 | tee "$H/logs/e311-census-goal.log" | grep -v '^    ' | head -30

step "4. TraitDifferentialEquations' suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e311-tde-test.log" 2>&1; echo "tde exit $?")

step "5. sessions"
for p in f-unified-$L forks-unified-$L d-unified-$L t-unified-$L; do bash "$H/run.sh" "$p" 3 > /dev/null 2>&1; grep -E '^(1|2|3|fk-patched [123]|[123] )' "$H/logs/$p.log" | grep -o -E 'wall [0-9.]+|total [0-9.]+' | tr '\n' ' '; echo " $p"; done

step "6. the forks' steps' compiles"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && DATA=$R/forks-unified/data nice -n 10 "$U" --startup-file=no --project=env_forks \
    --trace-compile="$H/logs/e311-steps-tracecompile.jl" --trace-compile-timing "$W/steps_traced.jl" > "$H/logs/e311-steps.log" 2>&1)
grep -c 'CSV.var"#_taskforeach' "$H/logs/e311-steps-tracecompile.jl" | sed 's/^/task closures of CSV compiled in the steps: /'

step "7. NetworkDynamics (E-310 (b))"
(cd "$R/ndport" && bash scripts/u_workload.sh e310b-warmup 1 && bash scripts/u_workload.sh e310b 2)

step "8. battery $L"
bash "$R/experiments/unification/stack/battery.sh" julia-unified "$L"
step "8b. checks"
(cd "$R/forks-unified" && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
(cd "$R/TraitReport-unified" && JULIA=$U LOCK=$H/.lock bash scripts/check.sh 2>&1 | tail -5)
step "done"
