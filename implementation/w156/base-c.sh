#!/bin/bash
# W-156, third part: Base's test files of the brief on a built tree, one at a time, niced: subtype, core, ambiguous,
# worlds, detect_ambiguities(Base) (suites-c.sh), then Compiler/inline and Compiler/inference.
#     bash experiments/implementation/w156/base-c.sh <julia tree> <label>   -> logs/c-<label>-base-*.log, c-<label>-summary.log
set -u
H=$(cd "$(dirname "$0")" && pwd)
bash "$H/suites-c.sh" "$1" "$2" base detect
source "$H/../../../env.sh"
T=$(cd "$TW_ROOT" && cd "$1" && pwd); L=c-$2; S=$H/logs/$L-summary.log
for t in Compiler/inline Compiler/inference; do
  f=$H/logs/$L-base-$(basename $t).log; s=$(date +%s)
  nice -n 10 "$T/julia" --startup-file=no -e "Base.runtests([\"$t\"]; ncores=1)" > "$f" 2>&1; rc=$?
  echo "base $t | exit $rc | $(( $(date +%s) - s )) s | $(grep -E 'SUCCESS|FAILURE' "$f" | tail -1)" | tee -a "$S"
done
