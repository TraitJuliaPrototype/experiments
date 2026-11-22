#!/bin/bash
# W-19, sixth part: the checks on the series' head (wt/w19-julia), in order of what they reveal first:
# the gates in force (run_all.sh, the stage gates too), the library's suite as a file, the documentation's
# examples, Base's tests (precompile alone), then the micro-timings, the plain session and the nine loads.
#     bash j-run-head.sh <tag>      -> logs/j-*-<tag>.log
cd /p/projects/coen/julia-trait-bound
source env.sh >/dev/null 2>&1
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w19:$TW_ROOT/.julia-depot: JULIA_PKG_OFFLINE=true
ulimit -c 0
L=experiments/implementation/w19/logs; T=wt/w19-julia; tag=${1:-head}
hdr() { echo "== $(git -C $T rev-parse --short=10 HEAD) load $(cat /proc/loadavg) $(date +%T)"; }
{ hdr; bash experiments/implementation/gates/run_all.sh $T; echo "exit $?"; hdr; } > $L/j-gates-$tag.log 2>&1
{ hdr; cd TraitWorld; nice ../$T/julia --startup-file=no --project=. test/runtests.jl; echo "exit $?"; cd ..; hdr; } > $L/j-traitworld-$tag.log 2>&1
{ for s in intro tutorial strict; do hdr; echo "## $s"; (cd TraitWorld && nice -n 19 ../$T/julia --project=. --startup-file=no ../experiments/docs-examples/$s.jl; echo "exit $?"); done; hdr; } > $L/j-examples-$tag.log 2>&1
bash experiments/implementation/w19/j-run.sh $tag "subtype core worlds reflection Compiler/inference Compiler/invalidation Compiler/effects facts show precompile" "" micro plain
cd experiments/implementation/w19
PREP=1 bash f-loads.sh wt/w19-julia j-$tag > logs/j-loads-prep-$tag.log 2>&1
bash f-loads.sh wt/w19-julia j-$tag 2 > /dev/null 2>&1; mv logs/f-loads-j-$tag.log logs/j-loads-$tag.log
echo done > logs/j-head-$tag.done
