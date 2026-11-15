#!/bin/bash
# E-436 (and later rows): E-407's variants on `julia-next` with TraitWorld-unified, the baseline's path on
# `julia-unified` with TraitWorld-base, interleaved, two processes each. Logs: logs/<label>-*.log, IR in logs/<label>/.
#     bash run.sh <label> [runs]
set -u
H=$(cd "$(dirname "$0")" && pwd); source "$H/../env.sh"; cd "$H"
L=$1; R=${2:-2}
mkdir -p logs/$L
hdr() { echo "# $1 run $2 $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $3"; }
for r in $(seq 1 $R); do
  { hdr variants $r "julia-next $(git -C $TW_ROOT/julia-next rev-parse --short=10 HEAD) | TraitWorld $(git -C $TW_ROOT/TraitWorld-unified log -1 --format=%h)$(git -C $TW_ROOT/TraitWorld-unified diff --quiet || echo +dirty)"
    IRDIR=logs/$L nice -n 10 $JN --startup-file=no --project=$TW_ROOT/TraitWorld-unified variants.jl 2>&1; } > logs/$L-variants-$r.log
  { hdr baseline $r "julia-unified $(git -C $TW_ROOT/julia-unified rev-parse --short=10 HEAD) | TraitWorld-base $(git -C $TW_ROOT/TraitWorld-base log -1 --format=%h)"
    IRDIR=logs/$L nice -n 10 $JU --startup-file=no --project=$TW_ROOT/TraitWorld-base baseline.jl 2>&1; } > logs/$L-baseline-$r.log
done
tail -n +1 logs/$L-*.log
grep -c "ijl_isa\|ijl_subtype" logs/$L/*.ll
