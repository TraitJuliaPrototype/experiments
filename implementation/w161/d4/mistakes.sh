#!/bin/bash
# W-161, E-498: E-385's fifteen mistakes (W-136's cases, trait forms) on a Julia tree with a library tree, each a
# fresh process, the output as the user sees it in logs/<label>/<case>.<form>.out; then the table (summarize.py).
#     bash mistakes.sh <label> <julia tree> <library tree>
set -u
H=$(cd "$(dirname "$0")" && pwd); source "$H/../env.sh"
L=$1; J=$TW_ROOT/$2/julia; TW=$TW_ROOT/$3; C=$TW_ROOT/experiments/implementation/w136
O=$H/logs/$L; mkdir -p "$O"
STRICT="04a 05 06"
echo "E-498 mistakes $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $2 $(git -C $TW_ROOT/$2 log -1 --format=%h) | $3 $(git -C $TW log -1 --format=%h)" > "$O/run.log"
run() { local out=$1 f=$2; shift 2
  env JULIA_PKG_OFFLINE=true "$@" nice -n 10 timeout 300 $J -t 1 --startup-file=no --color=no --project=$TW "$f" > "$O/$out.out" 2>&1
  echo "$out exit $?" >> "$O/run.log"; }
for f in $C/cases/*.trait.jl; do
  b=$(basename "$f" .jl); c=${b%.*}; n=${c%%_*}
  run "$c.trait" "$f"
  case " $STRICT " in *" $n "*) run "$c.trait-strict" "$f" JULIA_TW_STRICT=1;; esac
done
python3 "$H/summarize.py" "$O" > "$O/summary.md"
