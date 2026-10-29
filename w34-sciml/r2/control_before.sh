#!/bin/bash
# E-239's control for E-168's session: setting D on TDE 3a51d95 (before R2), run as ttfx/run.sh runs D
# (a discarded warm-up and one session, two cores, under the old lock: exclusive). Logs: ttfx/logs/e239/Dbefore-*.log.
#     W=<scratch dir> control_before.sh
# Needs a TDE worktree at $W/TDE-3a51d95 (git -C TraitDifferentialEquations worktree add --detach $W/TDE-3a51d95 3a51d95)
# and $W/env_d_before: ttfx/env_d's Project and Manifest with the TDE paths pointing to the worktree, the rest absolute.
set -u; W=${W:?scratch dir}
cd /home/hellmann/Repos/julia-trait-bound/experiments/ttfx
export JULIA_PKG_GC_AUTO=false OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 MPLCONFIGDIR=$PWD/out/mpl
J=/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia
flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no --project=$W/env_d_before -e 'using Pkg; Pkg.precompile()' > logs/e239/before-precompile.log 2>&1
for k in w 1; do
  f=logs/e239/Dbefore-$k.log
  ( echo "# setting=D run=$k before R2: TDE 3a51d95 (a worktree) load=$(cut -d' ' -f1-3 /proc/loadavg)"
    export WL_SHAPE=matched WL_ORDER=A WL_SPEC=auto; unset JULIA_DEPOT_PATH JULIA_TW_STRICT
    flock /tmp/claude-1000/julia-review.lock bash -c 'echo "W $(date +%s.%N)"; taskset -c 0-1 ionice -c2 -n7 nice -n 19 timeout 300 "$@" 2>&1; echo "rc=$?"; echo "E $(date +%s.%N)"' _ env WL_D=trait $J --startup-file=no --compiled-modules=existing --pkgimages=existing --project=$W/env_d_before workload_d.jl out/png
  ) > $f
  echo "Dbefore-$k: $(python3 -I summarize.py $f | tail -1)"
done
