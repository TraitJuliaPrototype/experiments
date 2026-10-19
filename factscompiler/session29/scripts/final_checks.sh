#!/bin/bash
R=/home/hellmann/Repos/julia-trait-bound; J=$R/julia-1.13/julia; L=/tmp/claude-1000/julia-review.lock
STOCK=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia
P=/tmp/claude-1000/-home-hellmann-Repos-julia-trait-bound/e0c44133-0ba1-4a71-abd7-4611822ff738/scratchpad/probe3.jl
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
echo "### probe3 stock"; flock $L nice -n 10 timeout 900 $STOCK --startup-file=no $P 2>&1 | grep -E "visit|wrap" | head -4
echo "### probe3 patched"; flock $L nice -n 10 timeout 900 $J --startup-file=no $P 2>&1 | grep -E "visit|wrap" | head -4
echo "### suites"; flock $L /tmp/claude-1000/demos/after_build.sh 2>&1 | grep -v "^Test Summary"; grep -E "Test Failed|Error During|did not pass" /tmp/claude-1000/demos/tw-suite.log | head
echo "### micro"; cd $R/experiments/factscompiler
flock $L nice -n 10 timeout 900 $J --project=benv --startup-file=no recovery/dynmicro.jl 2>&1 | tail -4
N=2000 flock $L nice -n 10 timeout 900 $J --project=benv --startup-file=no recovery/dynmicro.jl 2>&1 | tail -4
cd $R/experiments/facts; flock $L nice -n 10 timeout 900 $J --project=../factscompiler/benv --startup-file=no typedbench.jl 2>&1 | tail -5
echo "### demo suites"; /tmp/claude-1000/demos/demo_suites.sh 2>&1 | tail -8
