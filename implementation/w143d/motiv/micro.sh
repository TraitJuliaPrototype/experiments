#!/bin/bash
# W-143d (E-540): ../../w19/motiv/h-micro.jl on Julia trees, interleaved, two processes each, in the same hour.
#     bash micro.sh <label> <tree>...        -> ../logs/micro-<label>.log
H=$(cd "$(dirname "$0")/.." && pwd); source "$H/env.sh"
label=$1; shift
log=$H/logs/micro-$label.log
echo "# W-143d micro $label | $(date -Is) | load-before $(cut -d' ' -f1-3 /proc/loadavg)" > $log
for round in 1 2; do for t in "$@"; do
  echo "== $t ($(git -C $TW_ROOT/$t rev-parse --short=10 HEAD)) round $round" >> $log
  nice -n 5 $TW_ROOT/$t/julia --startup-file=no -t 1 $TW_ROOT/experiments/implementation/w19/motiv/h-micro.jl >> $log 2>&1
done; done
echo "# done | $(date -Is) | load-after $(cut -d' ' -f1-3 /proc/loadavg)" >> $log
cat $log
