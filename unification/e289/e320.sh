#!/bin/bash
# E-320: the build with C-29 (the ambiguity report at a pattern member's call types) and C-75 (the G2 bit on a
# propagated result's edge instance), TraitWorld c20f9f4 (the detectors over a package's submodules):
#   1. the environments precompiled again; NetworkDynamics' load warnings;
#   2. the gates (m*, n*, f*);
#   3. TraitDifferentialEquations' suite (with its unused-casts check);
#   4. open issue 162 (c): detect_unused_casts over the ports (i162/unused_casts.jl);
#   5. the census of facts code failing G2 in the forks' session (e312/g2_census.jl; E-312: 1,191 of 3,468);
#   6. E-289's sessions (labels *-$1, a warm-up and 3 runs); NetworkDynamics' step d (one probe);
#   7. the census of plain CodeInstances of facts methods, the goal's environment;
#   8. the battery (label $1) and the ports' checks; NetworkDynamics' test subset.
# Logs: logs/e320-*.log here, the battery's in ../stack/logs/, NetworkDynamics' in ndport/logs/unified.
# PYENV must name the Python of E-284 (run.sh needs it). The forks' environments use the default depot
# throughout: an image their check builds in the workspace depot is the newest the goal's environment
# finds, and it loads slower there (E-320: the goal's imports 1.69-1.76 s against 1.03-1.04 s).
set -u
: "${PYENV:?set PYENV to the Python of E-284}"
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
L=${1:-w320}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
pc() { nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' 2>&1 | grep -v "^│\|^┌\|^└" | tail -2; }
W=$R/experiments/unification/w121; E=$R/experiments/unification

step "1. precompile"
pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
pc "$R/TraitReport-unified/env_t"; pc "$R/TraitReport-unified/env_pt"; pc "$R/TraitReport-unified/env_fu"
pc "$R/TraitDifferentialEquations-unified"; pc "$R/TraitMakie-unified"; pc "$R/TraitTables-unified"; pc "$R/TraitCSV-unified"
(cd "$R/experiments/ttfx" && nice -n 10 "$U" --startup-file=no --project="$H/env_d_unified" -e "using TraitDifferentialEquations, TraitMakie, TraitWorld" 2>&1 | tail -2)
(unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks"; pc "$R/forks-unified/env_upstream")
nice -n 10 "$U" --startup-file=no --project="$R/ndport/env_unified_r5" -e 'using Pkg; Pkg.precompile()' > "$H/logs/e320-nd-precompile-$L.log" 2>&1
(cd "$R/ndport" && nice -n 10 "$U" --startup-file=no --project=env_unified_r5 -e 'using NetworkDynamics' > "$H/logs/e320-nd-load-$L.log" 2>&1)
echo "NetworkDynamics' load warnings: $(grep -c 'WARNING' "$H/logs/e320-nd-load-$L.log")"; grep 'WARNING' "$H/logs/e320-nd-load-$L.log" | cut -c1-200 | head -8

step "2. gates"
bash "$E/gates/run_all.sh" julia-unified 'm[12]_*' > "$H/logs/e320-gates-m-$L.log" 2>&1; tail -1 "$H/logs/e320-gates-m-$L.log"
bash "$E/gates/run_all.sh" julia-unified '[nf]*' > "$H/logs/e320-gates-nf-$L.log" 2>&1; tail -1 "$H/logs/e320-gates-nf-$L.log"
grep -h -A6 '^FAIL' "$H/logs/e320-gates-m-$L.log" "$H/logs/e320-gates-nf-$L.log" | head -20

step "3. TraitDifferentialEquations' suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e320-tde-test-$L.log" 2>&1; echo "tde exit $?")
grep -E 'Testing .* tests passed|Test Summary|no casts|Fail|Error' "$H/logs/e320-tde-test-$L.log" | head -8

step "4. open issue 162 (c): unused casts over the ports"
uc() { (cd "$1" && nice -n 10 "$U" --startup-file=no --project="$2" "$E/i162/unused_casts.jl" "${@:3}" 2>&1 | grep -v '^Repro\|WARNING' ); }
{ uc "$R/TraitDifferentialEquations-unified" . TraitDifferentialEquations
  uc "$R/TraitMakie-unified" . TraitMakie
  uc "$R/TraitTables-unified" . TraitTables
  uc "$R/TraitCSV-unified" . TraitCSV
  (unset JULIA_DEPOT_PATH; uc "$R/forks-unified" env_forks Tables CSV DataFrames)
  uc "$R/ndport" env_unified_r5 NetworkDynamics; } | tee "$E/i162/ports-$L.log"

step "5. the census of facts code failing G2, the forks' session"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && DATA=data SCRIPT="$R/experiments/unification/w121/steps_traced.jl" nice -n 10 "$U" --startup-file=no --project=env_forks "$E/e312/g2_census.jl" CSV DataFrames Tables > "$E/e312/g2_census-forks-$L.log" 2>&1)
grep -v '^          ' "$E/e312/g2_census-forks-$L.log" | head -20

step "6. sessions"
for p in f-unified-$L forks-unified-$L d-unified-$L t-unified-$L; do bash "$H/run.sh" "$p" 3 > /dev/null 2>&1; grep -E '^(1|2|3|fk-patched [123]|[123] )' "$H/logs/$p.log" | grep -o -E 'wall [0-9.]+|total [0-9.]+' | tr '\n' ' '; echo " $p"; done
(cd "$R/ndport" && export OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 NDW_API=ports NDW_STACK=ports NDW_PASSES=again && \
    nice -n 10 "$U" --startup-file=no --threads=1 --project=env_unified_r5 scripts/e313_probe.jl > "logs/unified/e320-probe-$L.log" 2>&1)
grep -E '^P step_d|^T again d' "$R/ndport/logs/unified/e320-probe-$L.log"

step "7. census, the goal's environment"
(cd "$R/TraitReport-unified" && nice -n 10 "$U" --startup-file=no --project=env_fu "$W/policy_census.jl" TraitWorld TraitMakie CSV DataFrames) 2>&1 | tee "$H/logs/e320-census-goal-$L.log" | grep -v '^    ' | head -20

step "8. battery $L"
bash "$E/stack/battery.sh" julia-unified "$L"
step "8b. checks"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
(cd "$R/TraitReport-unified" && JULIA=$U LOCK=$H/.lock bash scripts/check.sh 2>&1 | tail -5)
(cd "$R/ndport" && nice -n 10 "$U" --startup-file=no -t 2 --project=env_unified scripts/r3_nd_tests.jl > "logs/unified/e320-ndtest-$L.log" 2>&1; echo "ndtest exit $?")
grep -E '^TEST ' "$R/ndport/logs/unified/e320-ndtest-$L.log"
step "done"
