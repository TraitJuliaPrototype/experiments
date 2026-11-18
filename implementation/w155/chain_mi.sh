#!/bin/bash
# W-155 (E-416 (e)): the cost of counting an edge that names a callee by its MethodInstance alone as outside
# the class, on the baseline julia-unified: deep.jl's walk with that rule against E-395's walk.
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; cd "$H"
JULIA_NUM_PRECOMPILE_TASKS=4 nice -n 10 $JU --startup-file=no --project=env_forks -e 'using Pkg; Pkg.precompile()' > logs/e416-mi-precompile.log 2>&1
for e in env_forks; do
  echo "== $e | load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified (the baseline binary) TraitWorld-w155 $(git -C $TW_ROOT/TraitWorld-w155 log -1 --format=%h) forks $(git -C $TW_ROOT/forks log -1 --format=%h) | $(date -Is)"
  nice -n 10 timeout 1800 $JU --startup-file=no --project=$e deep.jl $CSVFILE 2>&1 | grep -v "^ *$" | cut -c1-1200
done > logs/e416-mi.log 2>&1
