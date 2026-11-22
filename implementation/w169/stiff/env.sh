# E-537 (W-169): what every script of stiff/ shares. `source env.sh`; nothing here runs a measurement.
# Two settings, each with a depot of its own stacked before the shared one (compiled caches are written there):
#   H  the head: julia-next (683ea4fc16), the round's environment w159/envs/H/demo (TraitWorld, the ODE port,
#      PlainODE at their trees' heads); images written into agent-depots/w169s/H.
#   V  vanilla v1.13.2: envs/up (OrdinaryDiffEqRosenbrock and what it needs, the manifest of w159/envs/V/ndup,
#      nothing downloaded); images written into agent-depots/w169s/V, the round's V depot read behind it.
# One thread, BLAS on one thread, niced; fresh process per run.
S=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
R=$(cd "$S/../../../.." && pwd)
source "$R/env.sh" >/dev/null 2>&1
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 JULIA_PKG_GC_AUTO=false
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT JULIA_LOAD_PATH
ulimit -c 0
D=$R/.julia-depot/agent-depots/w169s
ENV_H=$R/experiments/implementation/w159/envs/H/demo
ENV_V=$S/envs/up
load() { cut -d' ' -f1-3 /proc/loadavg; }
rev() { echo "$(git -C "$1" rev-parse --short=10 HEAD)$([ -z "$(git -C "$1" status --porcelain --untracked-files=no 2>/dev/null)" ] || echo '*')"; }
jH() { JULIA_DEPOT_PATH=$D/H:$R/.julia-depot: nice -n 10 timeout -s KILL "${TO:-900}" "$R/julia-next/julia" \
         --startup-file=no --history-file=no -t 1 --project="$ENV_H" "$@"; }
jV() { JULIA_DEPOT_PATH=$D/V:$R/.julia-depot/agent-depots/w159/V:$R/.julia-depot: nice -n 10 timeout -s KILL "${TO:-900}" \
         "$R/julia-vanilla/julia" --startup-file=no --history-file=no -t 1 --project="$ENV_V" "$@"; }
jS() { case $1 in up) shift; jV "$@" ;; *) shift; jH "$@" ;; esac; }   # jS <stack> <args>: V for upstream
header() { echo "# E-537 $1 | $(date -Is) | load $(load) | $(hostname -s) | julia-next $(rev "$R/julia-next") | julia-vanilla $(rev "$R/julia-vanilla") | TraitWorld $(rev "$R/TraitWorld") | TDE $(rev "$R/TraitDifferentialEquations") | experiments $(rev "$R/experiments") | product setting, strict mode off, one thread, BLAS one thread"; }
# NetworkDynamics (§4): the round's environments, w159/envs/H/nd (the port: NetworkDynamics-unified on the ODE port) and
# w159/envs/V/ndup (upstream's packages, ndport/env_upstream's manifest); run from ndport/
ENV_HND=$R/experiments/implementation/w159/envs/H/nd
ENV_VND=$R/experiments/implementation/w159/envs/V/ndup
jHnd() { (cd "$R/ndport" && JULIA_DEPOT_PATH=$D/H:$R/.julia-depot: nice -n 10 timeout -s KILL "${TO:-900}" "$R/julia-next/julia" \
         --startup-file=no --history-file=no -t 1 --project="$ENV_HND" "$@"); }
jVnd() { (cd "$R/ndport" && JULIA_DEPOT_PATH=$D/V:$R/.julia-depot/agent-depots/w159/V:$R/.julia-depot: nice -n 10 timeout -s KILL "${TO:-900}" \
         "$R/julia-vanilla/julia" --startup-file=no --history-file=no -t 1 --project="$ENV_VND" "$@"); }
