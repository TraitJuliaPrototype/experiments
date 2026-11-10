#!/bin/bash
# E-342: a member's check holds while it is a member (TraitWorld `unified` 5b3c427, on `unified` 999777ab77).
# Checks: TraitWorld's suite with test/recheck.jl, stack/recheck_packages.jl, both workloads, the forks' checks,
# TraitDifferentialEquations' suite. Logs: e289/logs/e342-*.log, stack/logs/w342-*.log, workloads/logs/w342-*.log.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); E=$R/experiments/unification
source "$R/env.sh"
U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
echo "unified $(git -C "$R/julia-unified" rev-parse --short HEAD) (binary $("$U" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')), TraitWorld $(git -C "$R/TraitWorld-unified" rev-parse --short HEAD), forks $(git -C "$R/forks-unified" rev-parse --short HEAD)"
step "TraitWorld's suite"
(cd "$R/TraitWorld-unified" && nice -n 10 "$U" --startup-file=no --project=. test/runtests.jl > "$E/stack/logs/w342-traitworld.log" 2>&1; echo "traitworld exit $?"; grep -A12 "TraitWorld: recheck.jl" "$E/stack/logs/w342-traitworld.log" | grep -E "^\S.*\|" )
step "the package gate"
nice -n 10 "$U" --startup-file=no "$E/stack/recheck_packages.jl" "$R/TraitWorld-unified" > "$E/stack/logs/w342-recheck-packages.log" 2>&1; echo "recheck_packages exit $?"; tail -1 "$E/stack/logs/w342-recheck-packages.log"
step "the workloads"
for w in columns ode; do
  nice -n 10 "$U" --startup-file=no --project="$R/TraitWorld-unified" "$E/workloads/$w.jl" > "$E/workloads/logs/w342-$w.log" 2>&1
  echo "$w exit $?"
done
step "the forks' checks"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
step "TraitDifferentialEquations' suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e342-tde-tests.log" 2>&1; echo "tde tests exit $?"; grep -E "Test Summary|Pass|Fail|Error" "$H/logs/e342-tde-tests.log" | tail -4)
step "done"
