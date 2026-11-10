#!/bin/bash
# E-346: the ambiguity report names only the ambiguities a membership creates
# (`unified` on e42047dba2, TraitWorld d107c36). Checks: the ambiguity gates (m2_ambiguity_predates
# new), TraitWorld's suite with test/strict_membership.jl (in the battery), the battery (label w346), the forks' checks,
# TraitDifferentialEquations' suite.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); E=$R/experiments/unification
source "$R/env.sh"
U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
echo "unified $(git -C "$R/julia-unified" rev-parse --short HEAD) (binary $("$U" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')), TraitWorld $(git -C "$R/TraitWorld-unified" rev-parse --short HEAD), forks $(git -C "$R/forks-unified" rev-parse --short HEAD)"
step "the ambiguity gates"
for g in m2_ambiguity_predates m2_ambiguity_called_before m2_ambiguity_report m2_ambiguity_arity n20_unmet_lookup n12_image_instances; do "$E/gates/run_all.sh" julia-unified "$g" 2>&1 | grep -E "^PASS|^FAIL|^    " | head -8; done
step "the ports' environments precompiled"
for p in "$R/TraitWorld-unified" "$R/TraitDifferentialEquations-unified"; do nice -n 10 "$U" --startup-file=no --project="$p" -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1; done
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1)
step "the forks' checks"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
step "TraitDifferentialEquations' suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e346-tde-tests.log" 2>&1; echo "tde tests exit $?"; grep -E "Test Summary|Pass|Fail|Error" "$H/logs/e346-tde-tests.log" | tail -4)
step "the battery"
(cd "$R" && bash experiments/unification/stack/battery.sh julia-unified w346 2>&1 | tail -40)
grep -E "^strict mode" "$E/stack/logs/w346-traitworld.log"
step "done"
