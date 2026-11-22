#!/bin/bash
# E-537 §4: NetworkDynamics' step d told apart (nd_steady.jl). The cells: the port (NDW_API=ports) on the head;
# upstream's packages on vanilla with NDW_API=ports (Rodas5, saveat: the port's variant) and NDW_API=upstream
# (Rodas5P, no saveat: E-514's run). time: P rounds, interleaved; profile: one run each.
#     bash nd.sh <label> time [P=3]   |   bash nd.sh <label> profile      -> logs/nd-<label>.log
source "$(cd "$(dirname "$0")" && pwd)/env.sh"
label=$1; mode=$2; P=${3:-3}
[ "$mode" = profile ] && P=1
LOG=$S/logs/nd-$label.log
header "nd $label: $mode, $P rounds | ndport $(rev "$R/ndport") NetworkDynamics-unified $(rev "$R/ndport/pkgs/NetworkDynamics-unified")" > "$LOG"
CELLS=${CELLS:-"H:ports V:ports V:upstream"}
for r in $(seq 1 "$P"); do for c in $CELLS; do
  s=${c%%:*}; api=${c##*:}
  echo "== round $r | $s api=$api | load $(load)" >> "$LOG"
  if [ "$s" = H ]; then out=$(NDW_STACK=ports NDW_API=$api jHnd "$S/nd_steady.jl" "$mode" 2>&1); rc=$?
  else out=$(NDW_STACK=upstream NDW_API=$api jVnd "$S/nd_steady.jl" "$mode" 2>&1); rc=$?; fi
  echo "$out" | grep -q Precompiling && { echo "# FAIL: precompiled" >> "$LOG"; exit 1; }
  echo "$out" | grep -E '^(R|P) |ERROR|error' | head -200 >> "$LOG"
  echo "-- rc $rc | load $(load)" >> "$LOG"
done; done
echo "# done $(date -Is) | load $(load)" >> "$LOG"
