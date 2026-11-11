#!/bin/bash
# E-362: bash run.sh [pattern] -- each case of cases/ as a script in a fresh process, its output and
# error kept as the user sees them in logs/<case>.<form>.out.
#   <case>.trait.jl : julia-unified with TraitWorld-unified   -> form "trait"
#                     again under strict mode (JULIA_TW_STRICT=1) for the cases of STRICT -> "trait-strict"
#   <case>.plain.jl : julia-vanilla                            -> form "plain"
#                     again on julia-unified, without the library, as a control -> "plain-unified"
# One process at a time. Then summarize.py writes logs/summary.md.
set -u
H=$(cd "$(dirname "$0")" && pwd); cd "$H"; R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
U=$R/julia-unified/julia; V=$R/julia-vanilla/julia; TW=$R/TraitWorld-unified
STRICT="04a 05 06"
rev() { git -C "$R/$1" log -1 --format=%h; }
echo "E-362 $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified $(rev julia-unified) julia-vanilla $(rev julia-vanilla) TraitWorld-unified $(rev TraitWorld-unified)" > logs/run.log
run() { # run <out> <julia> <project or ""> <file> [env...]
  local out=$1 j=$2 proj=$3 f=$4; shift 4
  env JULIA_PKG_OFFLINE=true "$@" nice -n 10 timeout 300 $j -t 1 --startup-file=no --color=no ${proj:+--project=$proj} "$f" > "logs/$out.out" 2>&1
  echo "$out exit $?" | tee -a logs/run.log
}
for f in cases/*${1:-}*.jl; do
  b=$(basename "$f" .jl); c=${b%.*}; form=${b##*.}; n=${c%%_*}
  if [ "$form" = trait ]; then
    run "$c.trait" "$U" "$TW" "$f"
    case " $STRICT " in *" $n "*) run "$c.trait-strict" "$U" "$TW" "$f" JULIA_TW_STRICT=1;; esac
  else
    run "$c.plain" "$V" "" "$f"
    run "$c.plain-unified" "$U" "" "$f"
  fi
done
python3 summarize.py > logs/summary.md
