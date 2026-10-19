#!/bin/bash
# After a Julia rebuild: TraitWorld's suite, the acceptance suite, the raytrace comparison.
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
cd /home/hellmann/Repos/julia-trait-bound/TraitWorld
JULIA_PKG_OFFLINE=true nice -n 19 timeout 3000 $J --project=. --startup-file=no -e 'using Pkg; Pkg.test()' > /tmp/claude-1000/demos/tw-suite.log 2>&1; echo "tw rc=$?"
grep -E "Test Summary|Test Failed|Error During|did not pass" /tmp/claude-1000/demos/tw-suite.log | head -20
cd /home/hellmann/Repos/julia-trait-bound/experiments/facts
JULIA_PKG_OFFLINE=true nice -n 19 timeout 1500 $J --project=../factscompiler/benv --startup-file=no acceptance_compiler.jl > /tmp/claude-1000/demos/acc.log 2>&1; echo "acc rc=$?"; tail -3 /tmp/claude-1000/demos/acc.log
cd /home/hellmann/Repos/julia-trait-bound/experiments/factscompiler
JULIA_PKG_OFFLINE=true nice -n 19 timeout 900 $J --project=benv --startup-file=no /tmp/claude-1000/demos/rt_cmp.jl 2>&1 | tail -3
cd /home/hellmann/Repos/julia-trait-bound/experiments/factscompiler && JULIA_PKG_OFFLINE=true nice -n 19 timeout 1500 ../../julia-1.13/julia --project=benv --startup-file=no recovery/rtopen.jl 2>&1 | tail -6
