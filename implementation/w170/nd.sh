#!/bin/bash
# W-170 (E-538): NetworkDynamics' step d (E-537's nd_steady.jl, unchanged, run from ndport/), before (B) and after (A),
# interleaved, P rounds of fresh processes; or one profile each, or the stacks under a declared field's type.
#     bash nd.sh <label> time [P=2]  |  bash nd.sh <label> profile  |  bash nd.sh <label> chains   -> logs/nd-<label>.log
# CELLS (default "B A") picks the settings; V: upstream's packages on vanilla (E-537's "the port's variant").
source "$(cd "$(dirname "$0")" && pwd)/env.sh"
label=$1; mode=$2; P=${3:-2}
[ "$mode" = time ] || P=1
LOG=$W/logs/nd-$label.log
header "nd $label: $mode, $P rounds | ndport $(rev "$R/ndport") | B NetworkDynamics $(rev "$R/wt/w170-base-nd")" > "$LOG"
for r in $(seq 1 "$P"); do for s in ${CELLS:-B A}; do
  echo "== round $r | $s | load $(load)" >> "$LOG"
  if [ "$s" = V ]; then out=$(NDW_STACK=upstream NDW_API=ports jVnd "$ST/nd_steady.jl" "$mode" 2>&1); rc=$?
  else out=$(NDW_STACK=ports NDW_API=ports jSnd "$s" "$ST/nd_steady.jl" "$mode" 2>&1); rc=$?; fi
  echo "$out" | grep -q Precompiling && { echo "# FAIL: precompiled" >> "$LOG"; exit 1; }
  echo "$out" | grep -E '^(R|P|C) |ERROR|error' | head -200 >> "$LOG"
  echo "-- rc $rc | load $(load)" >> "$LOG"
done; done
echo "# done $(date -Is) | load $(load)" >> "$LOG"
