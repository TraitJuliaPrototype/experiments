#!/usr/bin/env bash
# E-402: E-374's calls on the baseline library (TraitWorld-base, the tag) and D-1's forms on the head, interleaved, the
# same day, two processes each. Logs: logs/calls-<base|head>-<i>.log
#     ./run.sh [N]
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); source $H/../env.sh >/dev/null
mkdir -p $H/logs
for i in 1 2; do
  for which in base head; do
    if [ $which = base ]; then proj=$TW_ROOT/TraitWorld-base; script=$TW_ROOT/experiments/implementation/w145/calls/calls.jl
    else proj=$TW_ROOT/TraitWorld; script=$H/calls.jl; fi
    f=$H/logs/calls-$which-$i.log
    echo "# E-402 $which run $i $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified $(git -C $TW_ROOT/julia-unified log -1 --format=%h) TraitWorld $(git -C $proj log -1 --format=%h) | $(basename $script)" > $f
    nice -n 10 $JU --startup-file=no --project=$proj $script "$@" >> $f 2>&1
  done
done
