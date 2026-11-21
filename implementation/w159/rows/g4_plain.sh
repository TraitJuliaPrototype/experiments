#!/bin/bash
# W-159, G-4: E-381 (E-499's pairing): a session of plain code only (upstream CSV and DataFrames compiled plainly,
# w134/plain.jl): the load, the first work with its compile time, 200 repetitions; on vanilla (the baseline), on the
# head and on the tag (the control), without the library, with it loaded first, and loaded late (what its load ends,
# the work after). Interleaved; a warm-up and RUNS runs.
#     bash g4_plain.sh <label> [RUNS=3]       -> logs/g4-plain-<label>.log. About 4 minutes (E-499: 2 minutes for 5 cells x 4).
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; RUNS=${2:-3}
CSV=$R/experiments/interfaces/App/data/sample.csv
header "$LOGS/g4-plain-$label.log" "G-4 E-381 plain code's session (w134/plain.jl)" V H B
declare -A E
check V; E[V.up]=$(envfor V "$IMPL/w134/env_up" up) || exit 1; preflight V "${E[V.up]}" CSV DataFrames
for s in H B; do check $s
  E[$s.up]=$(envfor $s "$IMPL/w134/env_up" up) || exit 1; preflight $s "${E[$s.up]}" CSV DataFrames
  E[$s.lib]=$(envfor $s "$IMPL/w134/env_lib" lib) || exit 1; preflight $s "${E[$s.lib]}" CSV DataFrames TraitWorld; done
for i in w $(seq "$RUNS"); do
  CUT=300 HEAD=12 cell "V none run $i" jl V --project="${E[V.up]}" "$IMPL/w134/plain.jl" "$CSV" none || true
  for s in H B; do CUT=300 HEAD=12 cell "$s none run $i" jl $s --project="${E[$s.up]}" "$IMPL/w134/plain.jl" "$CSV" none || true; done
  for m in first late; do for s in H B; do
    CUT=300 HEAD=24 cell "$s $m run $i" jl $s --project="${E[$s.lib]}" "$IMPL/w134/plain.jl" "$CSV" $m || true
  done; done
done
footer
