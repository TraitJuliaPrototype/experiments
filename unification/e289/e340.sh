#!/bin/bash
# E-340: open issue 171 (a declared result asserted, never converted; IO's operations `Any`; handle1 joins a
# const result taken for its effects), C-57 (G2 at the call's own signature) and C-81 (a closed type's
# candidates in its contract), `unified` ef1233e79e, 0ee9e4f8a6, 18bbbf0841. Checks: the night's gates, the
# battery (label w340), the forks' digests and REPL transcript, TraitDifferentialEquations' suite. Measured,
# not gated: E-328's workloads, the image keep counts (JULIA_DEBUG_EXTERNAL_CIS=1) while TraitWorld and the
# forks precompile, the goal's task and the forks' session, a warm-up and 3 runs, the early build interleaved.
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
    grep -E '^(1|2|3|fk-patched [123]|[123] )' "$H/logs/$1.log" | grep -o -E 'imports [0-9.]+|read [0-9.]+|show [0-9.]+|write [0-9.]+|3_read_show [0-9.]+|wall [0-9.]+' | tr '\n' ' '; echo " $1"
}
step "the night's gates"
"$E/gates/run_all.sh" julia-unified 'n19_*' 2>&1 | tail -3
for g in n21_callsig_backedge n22_declared_assert n23_contract_image n20_unmet_lookup n18_closed_after_load; do "$E/gates/run_all.sh" julia-unified "$g" 2>&1 | grep -E "PASS|FAIL|    " | head -8; done
step "the keep counts while TraitWorld and the forks precompile"
(cd "$R/TraitWorld-unified" && JULIA_DEBUG_EXTERNAL_CIS=1 nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.precompile()' > "$H/logs/e340-keep-traitworld.log" 2>&1; grep -i -E "kept|dropped|g2" "$H/logs/e340-keep-traitworld.log" | tail -4)
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_DEBUG_EXTERNAL_CIS=1 nice -n 10 "$U" --startup-file=no --project=env_forks -e 'using Pkg; Pkg.precompile()' > "$H/logs/e340-keep-forks.log" 2>&1; grep -i -E "kept|dropped|g2" "$H/logs/e340-keep-forks.log" | tail -8)
step "the ports' environments precompiled"
for p in "$R/TraitReport-unified/env_fu" "$R/TraitReport-unified/env_t" "$R/TraitDifferentialEquations-unified"; do nice -n 10 "$U" --startup-file=no --project="$p" -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1; done
step "sessions"
sess f-early-w340a; sess f-unified-w340; sess forks-unified-w340; sess t-unified-w340; sess d-unified-w340; sess f-early-w340b
step "the forks' checks"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
step "E-328's workloads"
(cd "$R" && bash experiments/unification/e328/run.sh -w340 > /dev/null 2>&1; echo "e328 exit $?")
step "TraitDifferentialEquations' suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e340-tde-tests.log" 2>&1; echo "tde tests exit $?"; grep -E "Test Summary|Pass|Fail|Error" "$H/logs/e340-tde-tests.log" | tail -4)
step "done"
