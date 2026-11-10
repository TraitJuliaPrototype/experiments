#!/bin/bash
# E-358: bash run.sh <label> -- generates the packages, precompiles, then five orders (seeds 0..4) per kind, twice.
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../../.." && pwd); source "$R/env.sh"
label=$1; J=$R/julia-unified/julia; LOG=$H/logs/$label.log
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
rev() { git -C "$R/$1" log -1 --format=%h; }
[ -d "$H/pkgs" ] || "$J" --startup-file=no "$H/gen.jl" "$H/pkgs" 20
echo "# E-358 $label $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | unified $(rev julia-unified) TraitWorld-unified $(rev TraitWorld-unified) experiments $(rev experiments)" > "$LOG"
for kind in trait plain; do
  export JULIA_LOAD_PATH="$H/pkgs/$kind:$H/../env_lib:@stdlib"
  for pass in w 1 2; do
    for seed in 0 1 2 3 4; do
      echo "== $kind seed $seed pass $pass | load $(cut -d' ' -f1 /proc/loadavg)" >> "$LOG"
      nice -n 10 timeout 900 "$J" --startup-file=no "$H/comp.jl" $kind $seed 2>&1 | cut -c1-600 | head -30 >> "$LOG"
    done
  done
done
echo "# done $(date -Is)" >> "$LOG"
