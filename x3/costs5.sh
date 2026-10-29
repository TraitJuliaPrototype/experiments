#!/bin/bash
# E-227, E-228 (W-70, the Makie port's finish): fresh processes, one warm-up each (the precompile), then 2 runs.
#     bash experiments/x3/costs5.sh > experiments/x3/logs/costs-slice5.log
R=/home/hellmann/Repos/julia-trait-bound; X=$R/experiments/x3; J=$R/julia-1.13/julia; P=$R/experiments/ttfx/pyenv/bin/python
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 MPLCONFIGDIR=$R/experiments/ttfx/out/mpl
O=$(mktemp -d)
lock() { flock /tmp/claude-1000/julia-review.lock nice -n 19 "$@"; }
costs() { lock $J --startup-file=no --project=$X/$1 $X/costs5.jl $O 2>&1 | grep X3C5; }
session() { lock bash -c 'echo "T process $(date +%s.%N)"; "$@"' _ "$@" 2>&1; }
echo "# $(date -I) julia-1.13 $(git -C $R/julia-1.13 log -1 --format=%h) TraitWorld $(git -C $R/TraitWorld log -1 --format=%h) TraitMakie $(git -C $R/TraitMakie log -1 --format=%h); load $(cut -d' ' -f1-3 /proc/loadavg)"
for e in env env-nowl5; do costs $e > /dev/null; done
session $J --startup-file=no --project=$X/env $X/session5.jl $O > /dev/null; session $P $X/session5.py $O > /dev/null
for i in 1 2; do
  for e in env env-nowl5; do costs $e; done
done
for i in 1 2; do
  echo "## session $i, TraitMakie"; session $J --startup-file=no --project=$X/env $X/session5.jl $O
  echo "## session $i, matplotlib"; session $P $X/session5.py $O
done
ls -l $O/*.png | awk '{print "P", $5, $9}'
