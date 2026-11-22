cd /p/projects/coen/julia-trait-bound
source env.sh >/dev/null 2>&1
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w19:$TW_ROOT/.julia-depot: JULIA_PKG_OFFLINE=true
ulimit -c 0
L=experiments/implementation/w19/logs
T=wt/w19-julia
tag=${1:-t2}
{ echo "== $(git -C $T rev-parse --short=10 HEAD) load $(cat /proc/loadavg)"; nice $T/julia --startup-file=no -e 'Base.runtests(["subtype", "core"]; ncores=1)'; echo "exit $?"; echo "== load $(cat /proc/loadavg)"; } > $L/h-tests-$tag.log 2>&1
{ echo "== $(git -C $T rev-parse --short=10 HEAD) load $(cat /proc/loadavg)"; bash experiments/implementation/gates/run_all.sh $T 'm1_*'; bash experiments/implementation/gates/run_all.sh $T 'm2_*'; bash experiments/implementation/gates/run_all.sh $T 'n10_inputs'; bash experiments/implementation/gates/run_all.sh $T 'n2_*'; echo "== load $(cat /proc/loadavg)"; } > $L/h-gates-$tag.log 2>&1
