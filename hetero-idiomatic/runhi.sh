#!/bin/bash
# Runs hi1 and hi2 (E-134, E-144) in the product setting and the test bed `all`, one process at a
# time; logs in logs/<tag>-*.log. Usage: ./runhi.sh tag
tag=$1
cd "$(dirname "$0")"
for s in product all; do
  for f in hi1_cells hi2_shapes; do
    ./run.sh $s --project=. $f.jl > logs/$tag-$f-$s.log 2>&1
  done
done
echo "runhi $tag done"
