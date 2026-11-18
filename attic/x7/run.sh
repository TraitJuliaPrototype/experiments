#!/bin/bash
# E-182: every case of x7.jl in fresh sessions, two runs each where a time is measured; logs in logs/.   bash run.sh <tag>
set -uo pipefail
cd "$(dirname "$0")"; R=$(cd ../.. && pwd); tag=${1:-r1}; mkdir -p logs/$tag
J=$R/julia-1.13/julia
export JULIA_PKG_OFFLINE=true OPENBLAS_NUM_THREADS=1
one() {  # name, env assignments...
  local n=$1; shift
  ( echo "# $n julia-1.13=$(git -C $R/julia-1.13 log -1 --format=%h) TraitWorld=$(git -C $R/TraitWorld log -1 --format=%h) TraitMakie=$(git -C $R/TraitMakie log -1 --format=%h) load=$(cut -d' ' -f1-3 /proc/loadavg)"
    env "$@" flock /tmp/claude-1000/julia-review.lock taskset -c 0-1 nice -n 19 $J --startup-file=no --compiled-modules=existing --pkgimages=existing --project=env x7.jl 2>&1 ) > logs/$tag/$n.log
  grep -E "^X|ERROR|recompil|Precompiling" logs/$tag/$n.log | sed "s/^/$n: /"
}
for k in trait plain; do
  for e in direct latest; do one $k-world-$e X7_KIND=$k X7_CASE=world X7_ENTRY=$e; done
  for p in plain sparse; do for i in 1 2; do one $k-waist-$p-$i X7_KIND=$k X7_CASE=waist X7_PROV=$p; done; done
  for i in 1 2; do one $k-cost-$i X7_KIND=$k X7_CASE=cost; done
done
one trait-handover X7_KIND=trait X7_CASE=handover
