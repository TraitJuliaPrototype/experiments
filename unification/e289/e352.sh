#!/bin/bash
# E-352: the member hook in the compile queue (compiler C-31, lowering L-52's compiled use);
# E-353: strict mode infers an image's memberships at its load (W-133);
# E-354: open issue 174, the pairs of trait methods with no joint method.
# Checks: the gates (n24_hook_compile_queue, the image and ambiguity gates), the forks' checks,
# TraitDifferentialEquations' suite, the stack scripts, the detection tool, the goal's task, the battery (label w352).
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); E=$R/experiments/unification
source "$R/env.sh"
U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
echo "unified $(git -C "$R/julia-unified" rev-parse --short HEAD) (binary $("$U" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')), TraitWorld $(git -C "$R/TraitWorld-unified" rev-parse --short HEAD), forks $(git -C "$R/forks-unified" rev-parse --short HEAD)"
step "the image and ambiguity gates"
for g in n24_hook_compile_queue n12_image_instances n3_image_memberships m2_ambiguity_declared_super m2_ambiguity_predates m2_ambiguity_called_before m2_ambiguity_report m2_ambiguity_arity n20_unmet_lookup; do "$E/gates/run_all.sh" julia-unified "$g" 2>&1 | grep -E "^PASS|^FAIL|^    " | head -8; done
step "the ports' environments precompiled"
for p in "$R/TraitWorld-unified" "$R/TraitDifferentialEquations-unified"; do nice -n 10 "$U" --startup-file=no --project="$p" -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1; done
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1)
step "the forks' checks"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
step "TraitDifferentialEquations' suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e352-tde-tests.log" 2>&1; echo "tde tests exit $?"; grep -E "Test Summary|Pass|Fail|Error" "$H/logs/e352-tde-tests.log" | tail -4)
step "strict mode's report at an image's activation (E-349)"
nice -n 10 "$U" --startup-file=no "$E/stack/strict_activation.jl" "$R/TraitWorld-unified" 2>&1 | tail -1
step "strict mode's inference of an image's memberships at its load (E-353)"
nice -n 10 "$U" --startup-file=no "$E/stack/strict_load_membership.jl" "$R/TraitWorld-unified" 2>&1 | tail -1
step "the pairs of trait methods with no joint method (E-354)"
nice -n 10 "$U" --startup-file=no --project="$R/TraitDifferentialEquations-unified" "$H/e347_detect.jl" > "$H/logs/e354-detect-tde.log" 2>&1; tail -1 "$H/logs/e354-detect-tde.log"
(nice -n 10 "$U" --startup-file=no --project="$R/TraitReport-unified/env_t" "$H/e347_detect.jl" > "$H/logs/e354-detect-env_t.log" 2>&1; tail -1 "$H/logs/e354-detect-env_t.log")
step "the goal's task"
PYENV=${PYENV:-python3} bash "$H/run.sh" f-unified-w352 3 2>&1 | tail -5
step "the battery"
(cd "$R" && bash experiments/unification/stack/battery.sh julia-unified w352 2>&1 | tail -40)
grep -E "^strict mode" "$E/stack/logs/w352-traitworld.log"
step "done"
