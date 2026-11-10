#!/bin/bash
# E-360: bash run.sh <label> -- generate, precompile, then measure each package in a fresh process (twice).
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../../.." && pwd); source "$R/env.sh"
label=$1; J=$R/julia-unified/julia; LOG=$H/logs/$label.log
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1 JULIA_LOAD_PATH="@:$H/pkgs:@stdlib"
[ -d "$H/pkgs" ] || "$J" --startup-file=no "$H/gen.jl" "$H/pkgs"
rev() { git -C "$R/$1" log -1 --format=%h; }
echo "# E-360 $label $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | unified $(rev julia-unified) TraitWorld-unified $(rev TraitWorld-unified) TDE $(rev TraitDifferentialEquations-unified) TraitTables $(rev TraitTables-unified) TraitReport $(rev TraitReport-unified) experiments $(rev experiments)" > "$LOG"
m() { nice -n 10 timeout 900 "$J" --startup-file=no --project="$H/../env_demo" "$H/measure.jl" "$@" 2>&1 | cut -c1-600 | head -${HEADN:-12} >> "$LOG"; }
for pass in build 1 2; do
  echo "== pass $pass | load $(cut -d' ' -f1 /proc/loadavg)" >> "$LOG"
  for p in ColA0 ColA1; do m $p TraitTables; done
  for p in PColA0 PColA1; do m $p PlainTables; done
  for p in ProbA0 ProbA1 ProbA2; do m $p TraitDifferentialEquations; done
done
echo "# done $(date -Is)" >> "$LOG"
