#!/bin/bash
# E-348: activation ends an older entry in force for the same member, set and inputs (compiler C-84);
# E-349: strict mode reports an ambiguity at an image's activation (traits T-98);
# E-350: a member by its definition used before its @implement raises (lowering L-52)
# Checks: the image gates (n12_image_instances extended, n3_image_memberships), the ambiguity gates, the forks' checks,
# TraitDifferentialEquations' suite, the battery (label w348).
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); E=$R/experiments/unification
source "$R/env.sh"
U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
echo "unified $(git -C "$R/julia-unified" rev-parse --short HEAD) (binary $("$U" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')), TraitWorld $(git -C "$R/TraitWorld-unified" rev-parse --short HEAD), forks $(git -C "$R/forks-unified" rev-parse --short HEAD)"
step "the image and ambiguity gates"
for g in n12_image_instances n3_image_memberships m2_ambiguity_declared_super m2_ambiguity_predates m2_ambiguity_called_before m2_ambiguity_report m2_ambiguity_arity n20_unmet_lookup; do "$E/gates/run_all.sh" julia-unified "$g" 2>&1 | grep -E "^PASS|^FAIL|^    " | head -8; done
step "the ports' environments precompiled"
for p in "$R/TraitWorld-unified" "$R/TraitDifferentialEquations-unified"; do nice -n 10 "$U" --startup-file=no --project="$p" -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1; done
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1)
step "the forks' checks"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
step "TraitDifferentialEquations' suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e348-tde-tests.log" 2>&1; echo "tde tests exit $?"; grep -E "Test Summary|Pass|Fail|Error" "$H/logs/e348-tde-tests.log" | tail -4)
step "strict mode's report at an image's activation (E-349)"
nice -n 10 "$U" --startup-file=no "$E/stack/strict_activation.jl" "$R/TraitWorld-unified" 2>&1 | tail -1
step "the goal's task (E-350)"
PYENV=${PYENV:-python3} bash "$H/run.sh" f-unified-w348 3 2>&1 | tail -5
step "the battery"
(cd "$R" && bash experiments/unification/stack/battery.sh julia-unified w348 2>&1 | tail -40)
grep -E "^strict mode" "$E/stack/logs/w348-traitworld.log"
step "done"
