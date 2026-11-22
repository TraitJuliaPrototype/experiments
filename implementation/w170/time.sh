#!/bin/bash
# W-170 (E-538): E-537's cells of one problem (w169/stiff/run.jl, unchanged), before (B) and after (A), beside the plain
# twin, in fresh processes, interleaved (round robin over the cells, P rounds); each process 2 warm-up solves, then
# NT = 7 timed solves.
#     bash time.sh <label> <problem> "<cbs>" [P=3]      -> logs/time-<label>.log
# CELLS (default: B:port:box B:port:compiled A:port:box A:port:compiled A:plain:wrap A:plain:spec). The plain twin is
# PlainODE, the same code in both settings.
source "$(cd "$(dirname "$0")" && pwd)/env.sh"
label=$1; prob=$2; cbs=$3; P=${4:-3}
export BRUSS_N=${BRUSS_N:-16} NT=${NT:-7}
LOG=$W/logs/time-$label.log
header "time $label: $prob, cb $cbs, $P rounds, BRUSS_N=$BRUSS_N, NT=$NT" > "$LOG"
CELLS=${CELLS:-"B:port:box B:port:compiled A:port:box A:port:compiled A:plain:wrap A:plain:spec"}
for r in $(seq 1 "$P"); do for cb in $cbs; do for c in $CELLS; do
  IFS=: read -r s st fm <<< "$c"
  out=$(jS "$s" demo "$ST/run.jl" "$st" "$prob" "$cb" "$fm" 2>&1); rc=$?
  echo "$out" | grep -q Precompiling && { echo "# FAIL: $s $st $fm precompiled" >> "$LOG"; exit 1; }
  echo "== round $r | $s | rc $rc | load $(load)" >> "$LOG"
  echo "$out" | grep -E '^(R) |ERROR' | sed "s/^R /R $s /" >> "$LOG"
done; done; done
echo "# done $(date -Is) | load $(load)" >> "$LOG"
