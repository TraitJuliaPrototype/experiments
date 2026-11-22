# W-170 (E-538): what every script of w170/ shares. `source env.sh`; nothing here runs a measurement.
# Two settings on julia-next (683ea4fc16), each with a depot of its own before the shared one:
#   B  before: the library and the ODE port at the heads the round measured (TraitWorld 38200d3, TDE 06c28c3), in
#      worktrees of their own (wt/w170-base-tw, wt/w170-base-tde); envs/B/* made by w159/mkenv.py.
#   A  after: the branches w170 (wt/w170-tw, wt/w170-tde, and NetworkDynamics' port in wt/w170-nd); envs/A/*.
# PlainODE (the plain twin) is the same tree in both (TraitDifferentialEquations/baselines/PlainODE of each setting's
# tree, unchanged by W-170). One thread, BLAS on one thread, niced; a fresh process per run.
W=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
R=$(cd "$W/../../.." && pwd)
source "$R/env.sh" >/dev/null 2>&1
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 JULIA_PKG_GC_AUTO=false
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT JULIA_LOAD_PATH
ulimit -c 0
D=$R/.julia-depot/agent-depots/w170
ST=$R/experiments/implementation/w169/stiff          # E-537's programs, run from their own directory (read only)
load() { cut -d' ' -f1-3 /proc/loadavg; }
rev() { echo "$(git -C "$1" rev-parse --short=10 HEAD)$([ -z "$(git -C "$1" status --porcelain --untracked-files=no 2>/dev/null)" ] || echo '*')"; }
# jS <setting A|B> <env name> <args...>
jS() { local s=$1 e=$2; shift 2; JULIA_DEPOT_PATH=$D/$s:$R/.julia-depot: nice -n 10 timeout -s KILL "${TO:-900}" "$R/julia-next/julia" \
         --startup-file=no --history-file=no -t 1 --project="$W/envs/$s/$e" "$@"; }
jSnd() { local s=$1; shift; (cd "$R/ndport" && JULIA_DEPOT_PATH=$D/$s:$R/.julia-depot: nice -n 10 timeout -s KILL "${TO:-900}" "$R/julia-next/julia" \
         --startup-file=no --history-file=no -t 1 --project="$W/envs/$s/nd" "$@"); }
# V: upstream's packages on vanilla v1.13.2 (E-537's cell: w159/envs/V/ndup, NDW_STACK=upstream NDW_API=ports, the
# round's images read behind a depot of this experiment's own)
jVnd() { (cd "$R/ndport" && JULIA_DEPOT_PATH=$D/V:$R/.julia-depot/agent-depots/w169s/V:$R/.julia-depot/agent-depots/w159/V:$R/.julia-depot: \
         nice -n 10 timeout -s KILL "${TO:-900}" "$R/julia-vanilla/julia" --startup-file=no --history-file=no -t 1 \
         --project="$R/experiments/implementation/w159/envs/V/ndup" "$@"); }
# C and D, for the load's attribution: C the library's branch with the ODE port before (candidates 1, 2); D the library's
# branch with the ODE port at a candidate (wt/w170-mid-tde: 38fc6e6, candidate 3, for logs c5load/c5wl/c5; d061814, candidate 4, from c5ode4)
tw() { case $1 in A|C|D) echo "$R/wt/w170-tw" ;; *) echo "$R/wt/w170-base-tw" ;; esac; }
tde() { case $1 in A) echo "$R/wt/w170-tde" ;; D) echo "$R/wt/w170-mid-tde" ;; *) echo "$R/wt/w170-base-tde" ;; esac; }
header() { echo "# E-538 $1 | $(date -Is) | load $(load) | $(hostname -s) | julia-next $(rev "$R/julia-next") | B: TraitWorld $(rev "$(tw B)") TDE $(rev "$(tde B)") | A: TraitWorld $(rev "$(tw A)") TDE $(rev "$(tde A)")$( [ -d "$R/wt/w170-nd" ] && echo " NetworkDynamics $(rev "$R/wt/w170-nd")") | experiments $(rev "$R/experiments") | product setting, strict mode off, one thread, BLAS one thread"; }
