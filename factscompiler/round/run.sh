#!/bin/bash
# The measurement round of 2026-10-19 (quiet machine): call benchmarks, the quick subset, the
# demonstrators' rows, the full BaseBenchmarks; one job after another. Logs in round/logs/.
R=/home/hellmann/Repos/julia-trait-bound; F=$R/experiments/factscompiler; L=$F/round/logs
J=$R/julia-1.13/julia; FI=$R/julia-1.13/usr/lib/julia/facts/sys.so; FD=$TMPDIR/depot-facts:$HOME/.julia:
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=8
step() { echo "### $1 $(date +%T)"; }
cd $F
step calls
$J --startup-file=no --project=benv step1/callbench.jl > $L/callbench.log 2>&1; tail -5 $L/callbench.log
for m in plain all; do
  if [ $m = all ]; then A="-J $FI"; export JULIA_DEPOT_PATH=$FD; else A=""; unset JULIA_DEPOT_PATH; fi
  $J $A --startup-file=no --project=benv step3/untyped.jl > $L/untyped-$m.log 2>&1; echo "untyped $m"; tail -5 $L/untyped-$m.log
  $J $A --startup-file=no --project=step0/benv ic/sites.jl > $L/sites-$m.log 2>&1; tail -4 $L/sites-$m.log
done
unset JULIA_DEPOT_PATH
step quick
bash step0/scripts/run_quick.sh -final > $L/quick.log 2>&1; grep -E "^ALL|geomean" $L/quick.log | tail -18
step demonstrators
sed 's/JULIA_NUM_PRECOMPILE_TASKS=4/JULIA_NUM_PRECOMPILE_TASKS=8/; s/nice -n 10 //g' /tmp/claude-1000/demos/measure_all.sh > $F/round/measure_all.sh
bash $F/round/measure_all.sh > $L/demonstrators.log 2>&1; tail -40 $L/demonstrators.log
cp -r /tmp/claude-1000/demos/m $L/m 2>/dev/null
step basebenchmarks
MODES="plain all" bash step0/scripts/run_bench.sh > $L/bench.log 2>&1; tail -40 $L/bench.log
$J --startup-file=no scripts/compare.jl s0-plain s0-all > $L/compare-full.log 2>&1; head -25 $L/compare-full.log
$J --startup-file=no scripts/compare.jl full0 s0-plain > $L/compare-plain-vs-s28.log 2>&1; grep ALL $L/compare-plain-vs-s28.log
step done
