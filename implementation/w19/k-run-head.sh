#!/bin/bash
# W-19, seventh part: the checks on the series' head (wt/w19-julia), in order of what they reveal first: the gates in
# force (run_all.sh, the stage gates too), Base's tests (precompile alone), the library's suite as a file, the
# documentation's examples, the set-folds report in its three modes, then the micro-timings, the plain session and
# the nine loads. The trimmed programs: k-mbuilds.sh.
#     bash k-run-head.sh <tag> [steps]      -> logs/k-*-<tag>.log   (steps: gates tests tw ex folds micro plain loads)
cd /p/projects/coen/julia-trait-bound
source env.sh >/dev/null 2>&1
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w19:$TW_ROOT/.julia-depot: JULIA_PKG_OFFLINE=true
ulimit -c 0
L=experiments/implementation/w19/logs; T=wt/w19-julia; tag=${1:-head}; steps=" ${2:-gates tests tw ex folds micro plain loads} "
hdr() { echo "== $(git -C $T rev-parse --short=10 HEAD) load $(cat /proc/loadavg) $(date +%T)"; }
has() { echo "$steps" | grep -q " $1 "; }
if has gates; then { hdr; bash experiments/implementation/gates/run_all.sh $T; echo "exit $?"; hdr; } > $L/k-gates-$tag.log 2>&1; fi
if has tests; then
  { hdr; nice $T/julia --startup-file=no -e 'Base.runtests(split("subtype core worlds reflection Compiler/inference Compiler/invalidation Compiler/effects Compiler/verifytrim facts show"); ncores=1)'; echo "exit $?"; hdr; } > $L/k-tests-$tag.log 2>&1
  { hdr; nice $T/julia --startup-file=no -e 'Base.runtests(["precompile"]; ncores=1)'; echo "exit $?"; hdr; } > $L/k-tests-$tag-precompile.log 2>&1
fi
if has tw; then { hdr; cd TraitWorld; nice ../$T/julia --startup-file=no --project=. test/runtests.jl; echo "exit $?"; cd ..; hdr; } > $L/k-traitworld-$tag.log 2>&1; fi
if has ex; then { for s in intro tutorial strict; do hdr; echo "## $s"; (cd TraitWorld && nice -n 19 ../$T/julia --project=. --startup-file=no ../experiments/docs-examples/$s.jl; echo "exit $?"); done; hdr; } > $L/k-examples-$tag.log 2>&1; fi
if has folds; then
  A=experiments/implementation/audit
  { hdr; nice $T/julia --startup-file=no --project=experiments/implementation $A/set_folds.jl; echo "exit $?"; hdr; } > $L/k-folds-stub-$tag.log 2>&1
  { hdr; nice $T/julia --startup-file=no --project=TraitWorld $A/set_folds.jl --mode=traitworld; echo "exit $?"; hdr; } > $L/k-folds-traitworld-$tag.log 2>&1
  { hdr; nice $T/julia --startup-file=no --project=experiments/implementation $A/set_folds_images.jl; echo "exit $?"; hdr; } > $L/k-folds-images-$tag.log 2>&1
fi
if has micro; then
  { for i in 1 2; do for t in julia-vanilla $T; do echo "== $t $($t/julia --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)') round $i load $(cut -d' ' -f1-3 /proc/loadavg)"; nice -n 10 $t/julia --startup-file=no -t 1 experiments/implementation/w19/motiv/h-micro.jl; done; done; } > $L/k-micro-$tag.log 2>&1
fi
if has plain; then (cd experiments/implementation/w19 && RUNS=3 bash g-plain.sh k-$tag julia-vanilla wt/w19-julia > /dev/null 2>&1; mv logs/g-plain-k-$tag.log logs/k-plain-$tag.log); fi
if has loads; then
  (cd experiments/implementation/w19 && PREP=1 bash f-loads.sh wt/w19-julia k-$tag > logs/k-loads-prep-$tag.log 2>&1
   bash f-loads.sh wt/w19-julia k-$tag 2 > /dev/null 2>&1; mv logs/f-loads-k-$tag.log logs/k-loads-$tag.log)
fi
echo done > $L/k-head-$tag.done
