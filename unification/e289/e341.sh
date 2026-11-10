#!/bin/bash
# E-341: C-82, dispatch's lookup drops an unmet match only at a final pair and reports its cells (`unified`
# 999777ab77). Checks: the gates n18 to n23, the battery (label w341), the forks' digests and REPL transcript,
# TraitDifferentialEquations' suite. Counted: the unmet-pair census in the goal's, the forks' and the ODE port's
# environments (audit/unmet_open_pairs.jl). Measured, not gated: the goal's task and the forks' session.
set -u
: "${PYENV:?set PYENV (run.sh requires it)}"
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); E=$R/experiments/unification
source "$R/env.sh"
U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
echo "unified $(git -C "$R/julia-unified" rev-parse --short HEAD) (binary $("$U" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')), TraitWorld $(git -C "$R/TraitWorld-unified" rev-parse --short HEAD), forks $(git -C "$R/forks-unified" rev-parse --short HEAD)"
sess() {   # label
    bash "$H/run.sh" "$1" 3 > /dev/null 2>&1
    grep -E '^(1|2|3|fk-patched [123]|[123] )' "$H/logs/$1.log" | grep -o -E 'imports [0-9.]+|read [0-9.]+|show [0-9.]+|write [0-9.]+|wall [0-9.]+' | tr '\n' ' '; echo " $1"
}
step "the gates n18 to n23"
for g in n18_closed_after_load n19_io_trait n20_unmet_lookup n21_callsig_backedge n22_declared_assert n23_contract_image; do "$E/gates/run_all.sh" julia-unified "$g" 2>&1 | grep -E "^PASS|^FAIL|^    " | head -8; done
step "the ports' environments precompiled"
for p in "$R/TraitWorld-unified" "$R/TraitReport-unified/env_fu" "$R/TraitReport-unified/env_t" "$R/TraitDifferentialEquations-unified"; do nice -n 10 "$U" --startup-file=no --project="$p" -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1; done
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1)
step "the unmet-pair census"
(cd "$R/TraitReport-unified" && nice -n 10 "$U" --startup-file=no --project=env_fu "$E/audit/unmet_open_pairs.jl" CSV,DataFrames,TraitMakie 10 > "$E/audit/logs/unmet-open-pairs-fu-e341.log" 2>&1; head -3 "$E/audit/logs/unmet-open-pairs-fu-e341.log")
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks "$E/audit/unmet_open_pairs.jl" CSV,DataFrames 10 > "$E/audit/logs/unmet-open-pairs-forks-e341.log" 2>&1; head -3 "$E/audit/logs/unmet-open-pairs-forks-e341.log")
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. "$E/audit/unmet_open_pairs.jl" TraitDifferentialEquations 10 > "$E/audit/logs/unmet-open-pairs-tde-e341.log" 2>&1; head -3 "$E/audit/logs/unmet-open-pairs-tde-e341.log")
step "sessions"
sess f-early-w341a; sess f-unified-w341; sess forks-unified-w341; sess d-unified-w341; sess f-early-w341b
step "the forks' checks"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
step "TraitDifferentialEquations' suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e341-tde-tests.log" 2>&1; echo "tde tests exit $?"; grep -E "Test Summary|Pass|Fail|Error" "$H/logs/e341-tde-tests.log" | tail -4)
step "the battery"
(cd "$R" && bash experiments/unification/stack/battery.sh julia-unified w341 2>&1 | tail -40)
step "done"
