#!/bin/bash
# Runs E-143 (the interop scripts of experiments/hetero, unchanged) and E-134/E-144 (hi1, hi2) in the
# product setting and the test bed `all`, one process at a time; logs in logs/. Usage: ./runall.sh [tag]
tag=${1:-run}
cd "$(dirname "$0")"
for s in product all; do
  for f in hc1_filter hc4_dict hc7_product hc3_dynamic; do
    echo "== $f $s  load $(cut -d' ' -f1-3 /proc/loadavg)" > logs/$tag-$f-$s.log
    ./run.sh $s --project=. ../hetero/$f.jl >> logs/$tag-$f-$s.log 2>&1
    echo "== end  load $(cut -d' ' -f1-3 /proc/loadavg)" >> logs/$tag-$f-$s.log
  done
  for f in hi1_cells hi2_shapes; do
    ./run.sh $s --project=. $f.jl > logs/$tag-$f-$s.log 2>&1
  done
done
echo "runall $tag done"
