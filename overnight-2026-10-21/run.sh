#!/bin/bash
# W-39: the overnight measurements of 2026-10-21/22 on julia-1.13 2943086604 (W-33) and TraitWorld f06b82d,
# one job after another, niced, each through the shared lock. Logs in logs/; a line per part in logs/driver.log.
#   E-162  the NetworkDynamics workload, a measurement round: settings U, P0, N, P4, I, A0, five runs each
#          in P1's order, three in order B (U, P0, N, P4, I); logs in ndport/logs/night1*/
#   E-163  the round of 2026-10-20 again, on the new build: call benchmarks, the quick subset, the
#          demonstrators' rows, the full BaseBenchmarks in both modes and their comparison
#   E-164  W-16: the heterogeneous rows (interop and idiomatic), product and `all`, on a quiet machine
# Usage: bash run.sh [parts]   (default: "precompile e162 e163 e164")
set -u
R=/home/hellmann/Repos/julia-trait-bound
O=$R/experiments/overnight-2026-10-21; L=$O/logs; mkdir -p $L $L/demos
J=$R/julia-1.13/julia; FI=$R/julia-1.13/usr/lib/julia/facts/sys.so
LOCK=/tmp/claude-1000/julia-review.lock
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 OPENBLAS_NUM_THREADS=1
PARTS=${1:-"precompile e162 e163 e164"}
step() { echo "### $1 $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg)" | tee -a $L/driver.log; }
has() { [[ " $PARTS " == *" $1 "* ]]; }
ND=$R/ndport

if has precompile; then
  step "precompile the NetworkDynamics environments on the new build"
  cd $ND
  pc() {  # name, depot or "", extra julia flags...
    local name=$1 depot=$2; shift 2
    ( [ -n "$depot" ] && export JULIA_DEPOT_PATH=$depot:$HOME/.julia: || unset JULIA_DEPOT_PATH
      flock $LOCK nice -n 19 timeout 5400 $J "$@" --startup-file=no -e 'using Pkg; t = @elapsed Pkg.precompile(); println("precompile s=", round(t; digits = 1))' ) > $L/precompile-$name.log 2>&1
    echo "  $name: $(grep -E 'precompile s=|ERROR' $L/precompile-$name.log | tail -1)" | tee -a $L/driver.log
  }
  pc upstream "" --project=env_upstream
  pc port "" --project=env_port
  pc p3 $ND/depot-p3 --project=env_p3
  pc p4 $ND/depot-p4 --project=env_p4
  pc p6 $ND/depot-p6 --project=env_p6
  pc all $ND/depot-facts -J $FI --project=env_port
fi

if has e162; then
  step "E-162: the NetworkDynamics workload, P1's order, five runs per setting"
  cd $ND
  for s in U P0 N P4 I A0; do bash scripts/run_workload.sh night1 $s 5 2>&1 | tee -a $L/driver.log; done
  step "E-162: order B, three runs per setting"
  for s in U P0 N P4 I; do NDW_ORDER=simfirst bash scripts/run_workload.sh night1-orderB $s 3 2>&1 | tee -a $L/driver.log; done
  python3 -I scripts/summarize.py logs/night1/*.log > $L/e162-summary.txt 2>&1
  python3 -I scripts/summarize.py logs/night1-orderB/*.log > $L/e162-orderB-summary.txt 2>&1
  for f in logs/night1/*.log logs/night1-orderB/*.log; do
    echo "$f $(python3 -I scripts/compare_digests.py logs/p1/U-1.log $f | tail -1)"; done > $L/e162-digests.txt 2>&1
fi

if has e163; then
  F=$R/experiments/factscompiler; cd $F
  step "E-163: call benchmarks"
  flock $LOCK nice -n 19 $J --startup-file=no --project=benv step1/callbench.jl > $L/callbench.log 2>&1
  for m in plain all; do
    ( if [ $m = all ]; then A="-J $FI"; export JULIA_DEPOT_PATH=$TMPDIR/depot-facts:$HOME/.julia:; else A=""; unset JULIA_DEPOT_PATH; fi
      flock $LOCK nice -n 19 $J $A --startup-file=no --project=benv step3/untyped.jl > $L/untyped-$m.log 2>&1
      flock $LOCK nice -n 19 $J $A --startup-file=no --project=step0/benv ic/sites.jl > $L/sites-$m.log 2>&1 )
  done
  step "E-163: the quick subset"
  flock $LOCK bash step0/scripts/run_quick.sh -night1 > $L/quick.log 2>&1
  step "E-163: the demonstrators' rows"
  flock $LOCK nice -n 19 bash $O/measure_demos.sh > $L/demonstrators.log 2>&1
  step "E-163: the full BaseBenchmarks, both modes"
  ( export MODES="plain all"
    sed 's/s0-\$mode/night1-$mode/' step0/scripts/run_bench.sh > $O/run_bench_night1.sh
    flock $LOCK bash $O/run_bench_night1.sh > $L/bench.log 2>&1 )
  flock $LOCK $J --startup-file=no scripts/compare.jl night1-plain night1-all > $L/compare-full.log 2>&1
  flock $LOCK $J --startup-file=no scripts/compare.jl s0-plain night1-plain > $L/compare-plain-vs-round.log 2>&1
  flock $LOCK $J --startup-file=no scripts/compare.jl s0-all night1-all > $L/compare-all-vs-round.log 2>&1
fi

if has e164; then
  step "E-164: the heterogeneous rows (W-16)"
  cd $R/experiments/hetero-idiomatic && bash runall.sh night1 > $L/hetero.log 2>&1
fi
step done
