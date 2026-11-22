#!/bin/bash
# W-143e (E-541): the probes of plain code and the diagnostics after build 1, one Julia job at a time
H=$(cd "$(dirname "$0")" && pwd); cd "$H"; L=$1; R=$(cd ../../.. && pwd)
for p in plainfx widened; do for T in julia-vanilla julia-next wt/w143-julia; do
  ( echo "# $T $(git -C $R/$T rev-parse --short=10 HEAD) | motiv/$p.jl | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg)"
    TREE=$T; source env.sh >/dev/null 2>&1; timeout 600 nice -n 10 $JN --startup-file=no motiv/$p.jl 2>&1 | tail -20 ) > logs/$L-$p-$(basename $T).log
done; done
TREE=julia-next bash seq.sh head2 forks:diag/mi_why.jl facts:diag/mi_why.jl ode:diag/mi_why.jl
TREE=wt/w143-julia bash seq.sh $L forks:diag/mi_why.jl facts:diag/mi_why.jl ode:diag/mi_why.jl
( TREE=wt/w143-julia; source env.sh >/dev/null 2>&1; echo "# TraitWorld $(git -C $R/TraitWorld rev-parse --short=10 HEAD) tests on $TREE $(git -C $R/$TREE rev-parse --short=10 HEAD) | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg)"
  timeout 1200 nice -n 10 $JN --startup-file=no --project=$R/TraitWorld $R/TraitWorld/test/runtests.jl 2>&1 | tail -40; echo "# rc ${PIPESTATUS[0]} | $(date -Is)" ) > logs/traitworld-tests-$L.log
echo AFTER2DONE
