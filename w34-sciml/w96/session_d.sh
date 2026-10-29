#!/bin/bash
# E-248 (W-96): E-168's session in setting D (../../ttfx/workload_d.jl, the trait form) on TDE `w96` against a same-day
# control on TDE `w34` (../../ttfx/env_d as it is), each a discarded warm-up and <runs> sessions, run as ttfx/run.sh
# runs D (two cores, niced, the default depot) but each under `jl --exclusive`. Logs: ../../ttfx/logs/e248/<which>-<k>.log
#     W=<scratch dir> [TAG=<suffix>] session_d.sh <control|w96> [runs=1]
# w96 needs $W/env_d_w96: ttfx/env_d's Project and Manifest with TDE's paths pointing to the worktree
# ../../../TraitDifferentialEquations-w96, the other paths absolute (made here when missing), precompiled into the
# default depot (here, under jl --exclusive; logs/e248/<which>-precompile.log).
set -u; which=${1:?control or w96}; runs=${2:-1}
R=/home/hellmann/Repos/julia-trait-bound; T=$R/experiments/ttfx; J=$R/julia-1.13/julia
case $which in
  control) ENV=$T/env_d; TDE=$R/TraitDifferentialEquations ;;
  w96) W=${W:?scratch dir}; ENV=$W/env_d_w96; TDE=$R/TraitDifferentialEquations-w96
       if [ ! -f $ENV/Manifest.toml ]; then mkdir -p $ENV
         for f in Project.toml Manifest.toml; do
           sed -e "s#\"\.\./\.\./\.\./TraitDifferentialEquations\([/\"]\)#\"$R/TraitDifferentialEquations-w96\1#g" \
               -e "s#\"\.\./\.\./\.\./#\"$R/#g" $T/env_d/$f > $ENV/$f; done; fi ;;
  *) echo "control or w96"; exit 2 ;;
esac
cd $T; mkdir -p logs/e248 out/png
export JULIA_PKG_GC_AUTO=false OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 MPLCONFIGDIR=$T/out/mpl
unset JULIA_DEPOT_PATH JULIA_TW_STRICT
P=logs/e248/$which-precompile.log
[ -f $P ] || JULIA_NUM_PRECOMPILE_TASKS=2 $R/experiments/tools/jl --exclusive nice -n 19 timeout 3600 $J --startup-file=no --project=$ENV -e 'using Pkg; Pkg.precompile()' > $P 2>&1
for k in w $(seq 1 $runs); do
  f=logs/e248/$which-$k${TAG:-}.log
  ( echo "# setting=D run=$k which=$which env=$ENV TDE $(git -C $TDE log -1 --format=%h) TraitWorld $(git -C $R/TraitWorld log -1 --format=%h) TraitMakie $(git -C $R/TraitMakie log -1 --format=%h) julia-1.13 $(git -C $R/julia-1.13 log -1 --format=%h) load=$(cut -d' ' -f1-3 /proc/loadavg)"
    export WL_SHAPE=matched WL_ORDER=A WL_SPEC=auto
    $R/experiments/tools/jl --exclusive bash -c 'echo "W $(date +%s.%N)"; taskset -c 0-1 ionice -c2 -n7 nice -n 19 timeout 300 "$@" 2>&1; echo "rc=$?"; echo "E $(date +%s.%N)"' _ env WL_D=trait $J --startup-file=no --compiled-modules=existing --pkgimages=existing --project=$ENV workload_d.jl out/png
  ) > $f
  echo "$which-$k${TAG:-}: $(python3 -I summarize.py $f | tail -1)"
done
