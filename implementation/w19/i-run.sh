#!/bin/bash
# The fifth part's checks on wt/w19-julia: i-run.sh <tag> "<tests>" "<gate patterns>" [micro] [plain]
#   Base's tests (Base.runtests, one worker; "precompile" is run alone), the gates (run_all.sh with the
#   stub library), the micro-timings and the plain session of upstream CSV and DataFrames beside vanilla.
cd /p/projects/coen/julia-trait-bound
source env.sh >/dev/null 2>&1
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w19:$TW_ROOT/.julia-depot: JULIA_PKG_OFFLINE=true
ulimit -c 0
L=experiments/implementation/w19/logs
T=wt/w19-julia
set -f
tag=$1; tests=$2; gates=$3; extra=" $4 $5 "
hdr() { echo "== $(git -C $T rev-parse --short=10 HEAD) load $(cat /proc/loadavg)"; }
if [ -n "$tests" ]; then
  rest=$(echo " $tests " | sed 's/ precompile / /')
  { hdr; nice $T/julia --startup-file=no -e "Base.runtests(split(\"$rest\"); ncores=1)"; echo "exit $?"; echo "== load $(cat /proc/loadavg)"; } > $L/i-tests-$tag.log 2>&1
  if echo " $tests " | grep -q ' precompile '; then
    { hdr; nice $T/julia --startup-file=no -e 'Base.runtests(["precompile"]; ncores=1)'; echo "exit $?"; echo "== load $(cat /proc/loadavg)"; } > $L/i-tests-$tag-precompile.log 2>&1
  fi
fi
if [ -n "$gates" ]; then
  { hdr; for p in $gates; do bash experiments/implementation/gates/run_all.sh $T "$p"; done; echo "== load $(cat /proc/loadavg)"; } > $L/i-gates-$tag.log 2>&1
fi
if echo "$extra" | grep -q ' micro '; then
  { for i in 1 2; do for t in julia-vanilla $T; do echo "== $t $($t/julia --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)') round $i load $(cut -d' ' -f1-3 /proc/loadavg)"; nice -n 10 $t/julia --startup-file=no -t 1 experiments/implementation/w19/motiv/h-micro.jl; done; done; } > $L/i-micro-$tag.log 2>&1
fi
if echo "$extra" | grep -q ' plain '; then
  cd experiments/implementation/w19
  RUNS=3 bash g-plain.sh i-$tag julia-vanilla wt/w19-julia > /dev/null 2>&1; mv logs/g-plain-i-$tag.log logs/i-plain-$tag.log
fi
echo done > /p/projects/coen/julia-trait-bound/$L/i-$tag.done
