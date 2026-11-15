#!/usr/bin/env bash
# E-437: E-374's calls on the baseline (julia-unified, TraitWorld-base, E-374's script) and D-1's forms on the head
# (julia-next, TraitWorld-unified, calls.jl: no `@erasing`, the forwarders made where each method is defined),
# interleaved, the same day, two processes each. Logs: logs/calls-<base|head>-<i>.log
#     ./run.sh [N]
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); source $H/../env.sh >/dev/null
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w160:$TW_ROOT/.julia-depot/agent-depots/w151:$TW_ROOT/.julia-depot:
mkdir -p $H/logs
for i in 1 2; do
  for which in base head; do
    if [ $which = base ]; then proj=$TW_ROOT/TraitWorld-base; script=$TW_ROOT/experiments/unification/w145/calls/calls.jl; J=$JU; jt=julia-unified
    else proj=$TW_ROOT/TraitWorld-unified; script=$H/calls.jl; J=$JN; jt=julia-next; fi
    f=$H/logs/calls-$which-$i.log
    echo "# E-437 $which run $i $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $jt $(git -C $TW_ROOT/$jt log -1 --format=%h) TraitWorld $(git -C $proj log -1 --format=%h) | $(basename $script)" > $f
    nice -n 10 $J --startup-file=no --project=$proj $script "$@" >> $f 2>&1
  done
done
paste <(cut -c1-80 $H/logs/calls-base-1.log) <(cut -d'|' -f4 $H/logs/calls-base-2.log) <(cut -d'|' -f4 $H/logs/calls-head-1.log) <(cut -d'|' -f4 $H/logs/calls-head-2.log)
