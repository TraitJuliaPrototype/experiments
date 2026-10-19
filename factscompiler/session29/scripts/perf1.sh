#!/bin/bash
R=/home/hellmann/Repos/julia-trait-bound; J=$R/julia-1.13/julia
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
L=/tmp/claude-1000/julia-review.lock
run() { flock $L nice -n 19 timeout 2400 "$@"; }
for d in TraitMakie TraitDifferentialEquations TraitTables TraitCSV; do
  (cd $R/$d && run $J --project=. -e 'using Pkg; Pkg.test()' > /tmp/claude-1000/demos/$d-2.log 2>&1; echo "$d tests rc=$?")
done
echo "== typedbench"; (cd $R/experiments/facts && run $J --project=pkgs/env --startup-file=no typedbench.jl 2>&1 | tail -12)
echo "== dynmicro"; (cd $R/experiments/factscompiler && run $J --project=benv --startup-file=no recovery/dynmicro.jl 2>&1 | tail -20)
echo "== rtopen"; (cd $R/experiments/factscompiler && run $J --project=benv --startup-file=no recovery/rtopen.jl 2>&1 | tail -20)
