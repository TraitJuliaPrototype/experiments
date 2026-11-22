#!/bin/bash
# W-143e (E-541): what runs after a build of the branch, one Julia job at a time:  bash after.sh <label>
# the images and the census on the branch (wt/w143-julia), the diagnostics, the probes on the branch and the head.
H=$(cd "$(dirname "$0")" && pwd); cd "$H"; L=$1
TREE=wt/w143-julia bash run.sh $L images > /dev/null 2>&1
TREE=wt/w143-julia bash seq.sh $L forks facts ode forks:diag/mi_why.jl facts:diag/mi_why.jl ode:diag/mi_why.jl forks:diag/edges_of.jl facts:diag/edges_of.jl
R=$(cd ../../.. && pwd)
for T in julia-next wt/w143-julia; do
  for p in motiv/lb_entries.jl gate/f7_lower_bound_entries.jl; do
    ( echo "# $T $(git -C $R/$T rev-parse --short=10 HEAD) | $p | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg)"
      TREE=$T; source env.sh >/dev/null 2>&1; timeout 600 nice -n 10 $JN --startup-file=no --project=.. $p 2>&1 | tail -20 ) > logs/$L-$(basename $p .jl)-$(basename $T).log
  done
done
for T in julia-vanilla julia-next wt/w143-julia; do
  ( echo "# $T $(git -C $R/$T rev-parse --short=10 HEAD) | motiv/widened.jl | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg)"
    TREE=$T; source env.sh >/dev/null 2>&1; timeout 600 nice -n 10 $JN --startup-file=no motiv/widened.jl 2>&1 | tail -20 ) > logs/$L-widened-$(basename $T).log
done
echo AFTERDONE
