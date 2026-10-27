#!/bin/bash
# E-168: fresh sessions of the workload, one job at a time through the shared lock, two cores, niced.
#     bash run.sh <tag> "<settings>" [runs=2]
# A setting is a name with optional variants after a slash: py S U A C D Dp; /p perturbed shapes,
# /b plotting loaded after the first simulation (order B), /s strict mode on, /c the emulated cache (E-172), /n the function behind NoSpecialize (E-174, S, U, C), /x the split cache and /l a late load (E-177). E.g. "S S/p C/s D/b".
# Each setting first runs one discarded warm-up session (logs/<tag>/<setting>-w.log), then <runs>.
# Julia runs with --compiled-modules=existing --pkgimages=existing: a missing image is not compiled in
# the session; a log that shows precompiling or a rejected image is marked INVALID by summarize.py.
set -uo pipefail
cd "$(dirname "$0")"; H=$PWD; R=$(cd ../.. && pwd)
tag=$1; settings=$2; runs=${3:-2}
JP=$R/julia-1.13/julia; JS=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia
JF=(--startup-file=no --compiled-modules=existing --pkgimages=existing)
export JULIA_PKG_GC_AUTO=false OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 MPLCONFIGDIR=$H/out/mpl
mkdir -p logs/$tag out/png
for st in $settings; do
  s=${st%%/*}; mods=${st#"$s"}
  shape=matched; order=A; strict=0
  spec=auto; [[ $mods == *n* ]] && spec=nospec
  [[ $mods == *p* ]] && shape=perturbed; [[ $mods == *b* ]] && order=B; [[ $mods == *s* ]] && strict=1
  case $s in
    py) cmd=($H/pyenv/bin/python workload.py out/png); dep="" ;;
    S)  cmd=($JS "${JF[@]}" --project=env_up workload.jl out/png); dep="$H/depot-S:$HOME/.julia:" ;;
    U)  cmd=($JP "${JF[@]}" --project=env_up workload.jl out/png); dep="" ;;
    A)  cmd=($JP -J $R/julia-1.13/usr/lib/julia/facts/sys.so "${JF[@]}" --project=env_up workload.jl out/png); dep="$H/depot-A:$HOME/.julia:" ;;
    C)  cmd=($JP "${JF[@]}" --project=env_core workload.jl out/png); dep="$H/depot-C:$HOME/.julia:" ;;
    D)  cmd=(env WL_D=trait $JP "${JF[@]}" --project=env_d workload_d.jl out/png); dep="" ;;
    Dp) cmd=(env WL_D=plain $JP "${JF[@]}" --project=env_d workload_d.jl out/png); dep="" ;;
    *) echo "unknown setting $s"; exit 2 ;;
  esac
  if [[ $mods == *x* ]]; then   # E-177: the cache split by dependency set, its own environment
    export WL_CACHE_S=SessionCache${s}S WL_CACHE_P=SessionCache${s}P
    for k in "${!cmd[@]}"; do cmd[$k]=${cmd[$k]/--project=env_up/--project=env_split_$s}; cmd[$k]=${cmd[$k]/--project=env_d/--project=env_split_$s}; cmd[$k]=${cmd[$k]/--project=env_core/--project=env_split_$s}; done
  else unset WL_CACHE_S WL_CACHE_P; fi
  [[ $mods == *l* ]] && export WL_LATE=1 || unset WL_LATE
  if [[ $mods == *c* ]]; then   # E-172: the emulated cache across sessions, its own environment
    cv=$s; [ $spec = nospec ] && cv=${s}n; [ "${CI:-0}" = 1 ] && cv=${cv}ci; export WL_CACHE=SessionCache$cv; for k in "${!cmd[@]}"; do cmd[$k]=${cmd[$k]/--project=env_up/--project=env_cache_$cv}; cmd[$k]=${cmd[$k]/--project=env_d/--project=env_cache_$cv}; cmd[$k]=${cmd[$k]/--project=env_core/--project=env_cache_$cv}; done
  else unset WL_CACHE; fi
  name=${st//\//-}
  for i in w $(seq 1 $runs); do
    f=logs/$tag/$name-$i.log
    ( [ -n "$dep" ] && export JULIA_DEPOT_PATH=$dep || unset JULIA_DEPOT_PATH
      export WL_SHAPE=$shape WL_ORDER=$order WL_SPEC=$spec; [ $strict = 1 ] && export JULIA_TW_STRICT=1 || unset JULIA_TW_STRICT
      echo "# setting=$st run=$i shape=$shape order=$order strict=$strict load=$(cut -d' ' -f1-3 /proc/loadavg) depot=${JULIA_DEPOT_PATH:-default} julia-1.13=$(git -C $R/julia-1.13 log -1 --format=%h) TraitWorld=$(git -C $R/TraitWorld log -1 --format=%h)"
      flock /tmp/claude-1000/julia-review.lock bash -c 'echo "W $(date +%s.%N)"; taskset -c 0-1 ionice -c2 -n7 nice -n 19 timeout 300 "$@" 2>&1; echo "rc=$?"; echo "E $(date +%s.%N)"' _ "${cmd[@]}"
    ) > $f
    echo "$name-$i: $(python3 -I summarize.py $f | tail -1)"
  done
done
