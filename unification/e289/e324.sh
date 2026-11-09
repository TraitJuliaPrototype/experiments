#!/bin/bash
# E-324: C-63 narrowed: a match through Callable bounded by the member's own methods at the positions where the
# method's signature names Callable, an empty intersection resting on no call method; no global change world at a
# definition (`unified` branch c27-wip 23022b0ec7; 1daebeab81 alone, labels -w324a, narrowed empty intersections too;
# on E-321's build); TraitWorld 1745fc6. E-321 is the control (labels -w321). As E-321's runner, without the gates
# (run before: logs/e324-gates-*.log), with a traced setting D (its solve1's compiles), and E-323's control: the
# forks' display timed at an IOBuffer before the forks' `show` changes.
# PYENV must name the Python of E-284. Logs: logs/e324-*.log here, the sessions' in logs/.
set -u
: "${PYENV:?set PYENV to the Python of E-284}"
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
L=${1:-w324}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
PCLOG=$H/logs/e324-precompile-$L.log
pc() { nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' 2>&1 | tee -a "$PCLOG" | grep -v "^│\|^┌\|^└" | tail -2; }
W=$R/experiments/unification/w121; E=$R/experiments/unification

step "1. precompile"
pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
pc "$R/TraitReport-unified/env_t"; pc "$R/TraitReport-unified/env_pt"; pc "$R/TraitReport-unified/env_fu"
pc "$R/TraitDifferentialEquations-unified"; pc "$R/TraitMakie-unified"; pc "$R/TraitTables-unified"; pc "$R/TraitCSV-unified"
(cd "$R/experiments/ttfx" && nice -n 10 "$U" --startup-file=no --project="$H/env_d_unified" -e "using TraitDifferentialEquations, TraitMakie, TraitWorld" 2>&1 | tail -2)
(unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks"; pc "$R/forks-unified/env_upstream")
nice -n 10 "$U" --startup-file=no --project="$R/ndport/env_unified_r5" -e 'using Pkg; Pkg.precompile()' > "$H/logs/e324-nd-precompile-$L.log" 2>&1
(cd "$R/ndport" && nice -n 10 "$U" --startup-file=no --project=env_unified_r5 -e 'using NetworkDynamics' > "$H/logs/e324-nd-load-$L.log" 2>&1)
echo "warnings in the precompiles: $(grep -c 'WARNING' "$PCLOG")"; grep 'WARNING' "$PCLOG" | cut -c1-200 | sort | uniq -c | head -8
echo "NetworkDynamics' load warnings: $(grep -c 'WARNING' "$H/logs/e324-nd-load-$L.log")"; grep 'WARNING' "$H/logs/e324-nd-load-$L.log" | cut -c1-200 | head -8

step "3. TraitDifferentialEquations' suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e324-tde-test-$L.log" 2>&1; echo "tde exit $?")
grep -E 'Testing .* tests passed|Test Summary|no casts|Fail|Error' "$H/logs/e324-tde-test-$L.log" | head -8

step "6. sessions"
for p in f-unified-$L forks-unified-$L d-unified-$L t-unified-$L; do bash "$H/run.sh" "$p" 3 > /dev/null 2>&1; grep -E '^(1|2|3|fk-patched [123]|[123] )' "$H/logs/$p.log" | grep -o -E 'wall [0-9.]+|total [0-9.]+' | tr '\n' ' '; echo " $p"; done
(cd "$R/ndport" && export OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 NDW_API=ports NDW_STACK=ports NDW_PASSES=again && \
    nice -n 10 "$U" --startup-file=no --threads=1 --project=env_unified_r5 scripts/e313_probe.jl > "logs/unified/e324-probe-$L.log" 2>&1)
grep -E '^P step_d|^T again d' "$R/ndport/logs/unified/e324-probe-$L.log"

step "6b. setting D traced"
mkdir -p "$E/e324" "$H/out/png-e324trace"
(cd "$R/experiments/ttfx" && WL_D=trait WL_SHAPE=matched WL_ORDER=A WL_SPEC=auto JULIA_NUM_THREADS=1 nice -n 10 timeout 600 "$U" --startup-file=no --compiled-modules=existing --pkgimages=existing --project="$H/env_d_unified" --trace-compile=stderr --trace-compile-timing workload_d.jl "$H/out/png-e324trace" > "$E/e324/d-traced-$L.out" 2>&1)
grep '^T ' "$E/e324/d-traced-$L.out"; grep -c 'tupexpr' "$E/e324/d-traced-$L.out" | sed 's/^/tupexpr compiles: /'
step "6c. E-323's control: the forks' display at an IOBuffer"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && DATA=data nice -n 10 "$U" --startup-file=no --project=env_forks "$E/e323/show_time.jl" 2>&1 | tee "$E/e323/show_time-before-$L.log")
step "7. census, the goal's environment"
(cd "$R/TraitReport-unified" && nice -n 10 "$U" --startup-file=no --project=env_fu "$W/policy_census.jl" TraitWorld TraitMakie CSV DataFrames) 2>&1 | tee "$H/logs/e324-census-goal-$L.log" | grep -v '^    ' | head -20

step "8. battery $L"
bash "$E/stack/battery.sh" julia-unified "$L"
step "8b. checks"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
(cd "$R/TraitReport-unified" && JULIA=$U LOCK=$H/.lock bash scripts/check.sh 2>&1 | tail -5)
(cd "$R/ndport" && nice -n 10 "$U" --startup-file=no -t 2 --project=env_unified scripts/r3_nd_tests.jl > "logs/unified/e324-ndtest-$L.log" 2>&1; echo "ndtest exit $?")
grep -E '^TEST ' "$R/ndport/logs/unified/e324-ndtest-$L.log"
step "done"
