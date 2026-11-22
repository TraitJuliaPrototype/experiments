#!/bin/bash
# W-19, fifth part: the checks on T10's head (wt/w19-julia): Base's tests, precompile alone, the gates, the
# gates' copies for this part (gates/i-*.jl), the micro-timings, the plain session, the nine loads, and whether
# the library (TraitWorld, read only) loads.
cd /p/projects/coen/julia-trait-bound
bash experiments/implementation/w19/i-run.sh ${1:-t10} "subtype core worlds reflection Compiler/inference Compiler/invalidation Compiler/effects facts precompile" "m1_* m2_* n* f*" micro plain
source env.sh >/dev/null 2>&1
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w19:$TW_ROOT/.julia-depot: JULIA_PKG_OFFLINE=true
L=experiments/implementation/w19/logs; T=wt/w19-julia; tag=${1:-t10}
{ echo "== $(git -C $T rev-parse --short=10 HEAD) load $(cat /proc/loadavg)"
  for g in experiments/implementation/w19/gates/i-*.jl; do
    out=$(nice -n 10 $T/julia --startup-file=no --project=experiments/implementation $g 2>&1 < /dev/null); rc=$?
    [ $rc = 0 ] && echo "PASS $(basename $g)" || { echo "FAIL $(basename $g) (exit $rc)"; echo "$out" | tail -12 | sed 's/^/    /'; }
  done; } > $L/i-gates-copies-$tag.log 2>&1
{ echo "== $(git -C $T rev-parse --short=10 HEAD) load $(cat /proc/loadavg)"
  nice -n 10 $T/julia --startup-file=no --project=TraitWorld -e 'using TraitWorld; println("TraitWorld loaded")' 2>&1 | head -60
  echo "exit ${PIPESTATUS[0]}"; } > $L/i-traitworld-$tag.log 2>&1
cd experiments/implementation/w19
PREP=1 bash f-loads.sh wt/w19-julia i-$tag > logs/i-loads-prep-$tag.log 2>&1
bash f-loads.sh wt/w19-julia i-$tag 2 > /dev/null 2>&1; mv logs/f-loads-i-$tag.log logs/i-loads-$tag.log
echo done > logs/i-$tag-chain.done
