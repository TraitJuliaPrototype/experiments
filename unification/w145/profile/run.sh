#!/bin/bash
# E-388: every session's phases, first timed without the profiler, then profiled. One job at a time.
#     bash run.sh [tag] [sessions…]      -> logs/<session>[-tag].log
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../../.." && pwd); source "$R/env.sh" >/dev/null 2>&1
tag=${1:+-$1}; shift; S=${*:-"table ode forks upstream upstream-vanilla nd"}
U=$R/julia-unified/julia; V=$R/julia-vanilla/julia
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 DATA=$R/forks-unified/data NDROOT=$R/ndport
rev() { git -C "$R/$1" log -1 --format=%h; }
one() {  # name julia env session args…
    local name=$1 J=$2 env=$3 ses=$4; shift 4
    local log=$H/logs/$name$tag.log
    echo "# E-388 $name $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $J $($J --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)') TraitWorld $(rev TraitWorld-unified) TDE $(rev TraitDifferentialEquations-unified) forks $(rev forks-unified) | one thread, product setting, strict mode off" > "$log"
    PROF=0 nice -n 10 $J -t 1 --startup-file=no --project=$env $H/prof.jl $H/sessions/$ses "$@" > /dev/null 2>&1      # a warm-up
    PROF=0 nice -n 10 $J -t 1 --startup-file=no --project=$env $H/prof.jl $H/sessions/$ses "$@" >> "$log" 2>&1
    nice -n 10 $J -t 1 --startup-file=no --project=$env $H/prof.jl $H/sessions/$ses "$@" >> "$log" 2>&1
    echo "# done $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg)" >> "$log"
}
for s in $S; do
    case $s in
        table) one table $U $R/TraitReport-unified/env_t table.jl $R/experiments/interfaces/App/data/sample.csv /tmp/prof_t.png ;;
        ode) one ode $U $H/../../w134/env_demo ode.jl ;;
        forks) one forks $U $R/forks-unified/env_forks frames.jl ;;
        upstream) one upstream $U $R/forks-unified/env_upstream frames.jl ;;
        upstream-vanilla) one upstream-vanilla $V $R/forks-unified/env_upstream frames.jl ;;
        nd) (cd $R/ndport && OPENBLAS_NUM_THREADS=1 NDW_API=ports NDW_STACK=ports NDW_PASSES=first,again,params,changed,graphtype one nd $U $R/ndport/env_unified_r5 nd.jl) ;;
    esac
done
