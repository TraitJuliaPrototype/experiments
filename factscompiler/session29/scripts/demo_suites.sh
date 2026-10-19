#!/bin/bash
# The demonstrators' test suites and the examples, on the current build.
R=/home/hellmann/Repos/julia-trait-bound; J=$R/julia-1.13/julia
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
for p in TraitTables TraitCSV TraitMakie TraitDifferentialEquations; do
  cd $R/$p; flock /tmp/claude-1000/julia-review.lock nice -n 10 timeout 3600 $J --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > /tmp/claude-1000/demos/suite-$p.log 2>&1
  echo "$p rc=$? $(grep -cE 'Test Failed|Error During' /tmp/claude-1000/demos/suite-$p.log) failures"
done
cd $R/experiments/examples && nice -n 10 timeout 5400 bash run_all.sh > /tmp/claude-1000/demos/examples.log 2>&1; echo "examples rc=$?"; grep -E "fail" /tmp/claude-1000/demos/examples.log | grep -v " 0 fail" | head; tail -2 /tmp/claude-1000/demos/examples.log
