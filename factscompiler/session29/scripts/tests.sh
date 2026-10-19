#!/bin/bash
# Each demonstrator's test suite on julia-1.13 with the compiler's facts mode (session 29), one at a time.
R=/home/hellmann/Repos/julia-trait-bound
J=$R/julia-1.13/julia
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
for d in TraitTables TraitCSV TraitMakie TraitDifferentialEquations TraitReport; do
  echo "== $d $(date +%T)"
  ( cd $R/$d && flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 2400 $J --project=. -e 'using Pkg; Pkg.test()' > /tmp/claude-1000/demos/$d.log 2>&1; echo "rc=$?" )
  grep -E "Test Summary|tests passed|did not pass|errored|Test Failed|Error During" /tmp/claude-1000/demos/$d.log | head -8
done
