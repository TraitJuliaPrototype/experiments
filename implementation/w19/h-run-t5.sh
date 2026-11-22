cd /p/projects/coen/julia-trait-bound
source env.sh >/dev/null 2>&1
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w19:$TW_ROOT/.julia-depot: JULIA_PKG_OFFLINE=true
ulimit -c 0
L=experiments/implementation/w19/logs
T=wt/w19-julia
tag=t5
{ echo "== $(git -C $T rev-parse --short=10 HEAD) load $(cat /proc/loadavg)"; nice $T/julia --startup-file=no -e 'Base.runtests(["subtype", "core", "worlds", "reflection", "Compiler/inference", "Compiler/invalidation"]; ncores=1)'; echo "exit $?"; echo "== load $(cat /proc/loadavg)"; } > $L/h-tests-$tag.log 2>&1
{ echo "== $(git -C $T rev-parse --short=10 HEAD) load $(cat /proc/loadavg)"; nice $T/julia --startup-file=no -e 'Base.runtests(["precompile"]; ncores=1)'; echo "exit $?"; echo "== load $(cat /proc/loadavg)"; } > $L/h-tests-$tag-precompile.log 2>&1
{ echo "== $(git -C $T rev-parse --short=10 HEAD) load $(cat /proc/loadavg)"; for p in 'm1_*' 'm2_*' 'n*' 'f*'; do bash experiments/implementation/gates/run_all.sh $T "$p"; done; echo "== load $(cat /proc/loadavg)"; } > $L/h-gates-$tag.log 2>&1
{ for i in 1 2; do for t in julia-vanilla $T; do echo "== $t $($t/julia --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)') round $i load $(cut -d' ' -f1-3 /proc/loadavg)"; nice -n 10 $t/julia --startup-file=no -t 1 experiments/implementation/w19/motiv/h-micro.jl; done; done; } > $L/h-micro-$tag.log 2>&1
cd experiments/implementation/w19
RUNS=3 bash g-plain.sh h-$tag julia-vanilla wt/w19-julia > /dev/null 2>&1; mv logs/g-plain-h-$tag.log logs/h-plain-$tag.log
PREP=1 bash f-loads.sh wt/w19-julia h-$tag > logs/h-loads-prep-$tag.log 2>&1
bash f-loads.sh wt/w19-julia h-$tag 2 > /dev/null 2>&1; mv logs/f-loads-h-$tag.log logs/h-loads-$tag.log
echo done > logs/h-$tag-chain.done
