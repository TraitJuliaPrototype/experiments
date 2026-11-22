#!/bin/bash
# W-19, sixth part: the checks on a group's last part (wt/w19-julia): every gate, the gates' copies
# (gates/i-*.jl), Base's tests named, and with "lib" the library's suite and the examples.
#     bash j-run-mid.sh <tag> "<tests>" [lib]     -> logs/j-*-<tag>.log
cd /p/projects/coen/julia-trait-bound
source env.sh >/dev/null 2>&1
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w19:$TW_ROOT/.julia-depot: JULIA_PKG_OFFLINE=true
ulimit -c 0
L=experiments/implementation/w19/logs; T=wt/w19-julia; tag=$1; tests=$2
hdr() { echo "== $(git -C $T rev-parse --short=10 HEAD) load $(cat /proc/loadavg) $(date +%T)"; }
{ hdr; bash experiments/implementation/gates/run_all.sh $T; echo "exit $?"; hdr; } > $L/j-gates-$tag.log 2>&1
{ hdr; for g in experiments/implementation/w19/gates/i-*.jl; do
    out=$(nice -n 10 $T/julia --startup-file=no --project=experiments/implementation $g 2>&1 < /dev/null); rc=$?
    [ $rc = 0 ] && echo "PASS $(basename $g)" || { echo "FAIL $(basename $g) (exit $rc)"; echo "$out" | tail -8 | sed 's/^/    /'; }
  done; hdr; } > $L/j-gates-copies-$tag.log 2>&1
if [ "$3" = lib ]; then
  { hdr; cd TraitWorld; nice ../$T/julia --startup-file=no --project=. test/runtests.jl; echo "exit $?"; cd ..; hdr; } > $L/j-traitworld-$tag.log 2>&1
  { for s in intro tutorial strict; do hdr; echo "## $s"; (cd TraitWorld && nice -n 19 ../$T/julia --project=. --startup-file=no ../experiments/docs-examples/$s.jl; echo "exit $?"); done; hdr; } > $L/j-examples-$tag.log 2>&1
fi
[ -n "$tests" ] && bash experiments/implementation/w19/j-run.sh $tag "$tests" ""
echo done > $L/j-mid-$tag.done
