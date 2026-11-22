#!/bin/bash
# E-537: the steady state, every way and form of one problem, in fresh processes, interleaved (round robin over the
# cells, P rounds); each process: 2 warm-up solves, then NT = 7 timed solves (run.jl, mode time).
#     bash time.sh <label> <problem> "<cbs>" [P=3]      -> logs/time-<label>.log
# The cells: port box, port compiled, plain wrap, plain spec, up auto, up full. BRUSS_N defaults to 16.
source "$(cd "$(dirname "$0")" && pwd)/env.sh"
label=$1; prob=$2; cbs=$3; P=${4:-3}
export BRUSS_N=${BRUSS_N:-16} NT=${NT:-7}
LOG=$S/logs/time-$label.log
header "time $label: $prob, cb $cbs, $P rounds, BRUSS_N=$BRUSS_N, NT=$NT" > "$LOG"
CELLS="port:box port:compiled plain:wrap plain:spec up:auto up:full"
for r in $(seq 1 "$P"); do for cb in $cbs; do for c in $CELLS; do
  st=${c%%:*}; fm=${c##*:}
  out=$(jS "$st" "$S/run.jl" "$st" "$prob" "$cb" "$fm" 2>&1); rc=$?
  echo "$out" | grep -q Precompiling && { echo "# FAIL: $st $fm precompiled" >> "$LOG"; exit 1; }
  echo "== round $r | rc $rc | load $(load)" >> "$LOG"
  echo "$out" | grep -E '^(S|R) |ERROR' >> "$LOG"
done; done; done
echo "# done $(date -Is) | load $(load)" >> "$LOG"
