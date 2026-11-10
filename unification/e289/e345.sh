#!/bin/bash
# E-345: a member by its definition declares its entry; its parameters from the declared supertype; the records
# forgotten by a loop (TraitWorld after 6871ea9, on `unified` e42047dba2). Checks: TraitWorld's suite with
# test/declared.jl, recheck_packages.jl, both workloads, the forks' checks, TDE's suite, the goal's environment
# loaded with the sync's time.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); E=$R/experiments/unification
source "$R/env.sh"
U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
echo "unified $(git -C "$R/julia-unified" rev-parse --short HEAD) (binary $("$U" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')), TraitWorld $(git -C "$R/TraitWorld-unified" rev-parse --short HEAD), forks $(git -C "$R/forks-unified" rev-parse --short HEAD)"
step "TraitWorld's suite"
(cd "$R/TraitWorld-unified" && nice -n 10 "$U" --startup-file=no --project=. test/runtests.jl > "$E/stack/logs/w345-traitworld.log" 2>&1; echo "traitworld exit $?"; grep -cE "^Test Summary" "$E/stack/logs/w345-traitworld.log")
step "the package gate"
nice -n 10 "$U" --startup-file=no "$E/stack/recheck_packages.jl" "$R/TraitWorld-unified" > "$E/stack/logs/w345-recheck-packages.log" 2>&1; echo "recheck_packages exit $?"; tail -2 "$E/stack/logs/w345-recheck-packages.log"
step "the workloads"
for w in columns ode; do
  nice -n 10 "$U" --startup-file=no --project="$R/TraitWorld-unified" "$E/workloads/$w.jl" > "$E/workloads/logs/w345-$w.log" 2>&1
  echo "$w exit $?"
done
step "the ports' environments precompiled"
for p in "$R/TraitDifferentialEquations-unified" "$R/TraitReport-unified/env_fu" "$R/TraitReport-unified/env_t"; do nice -n 10 "$U" --startup-file=no --project="$p" -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1; done
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1)
step "the forks' checks"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
step "TraitDifferentialEquations' suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e345-tde-tests.log" 2>&1; echo "tde tests exit $?")
step "the goal's environment: the load and the sync"
(cd "$R/TraitReport-unified" && nice -n 10 "$U" --startup-file=no --project=env_fu -e '
    t0 = time(); using TraitWorld, CSV, DataFrames, TraitMakie; println("load ", round(time() - t0, digits = 2), " s")
    n = Int(ccall(:jl_activated_memberships_count, Csize_t, ()))
    for k in 1:3
        TraitWorld._ENTRY_CURSOR[] = 0
        t = time_ns(); TraitWorld._sync_image_records!(); dt = (time_ns() - t) / 1e6
        println("activated ", n, "; full sync ", k, ": ", round(dt, digits = 2), " ms; checked ", sum(length, values(TraitWorld._CHECKED_RESULTS)), " fixed ", sum(length, values(TraitWorld._FIXED_CALLS)))
    end' 2>&1 | tail -4)
step "done"
