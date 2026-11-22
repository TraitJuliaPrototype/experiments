#!/bin/bash
# W-167: W-159's g4_plain.sh (E-515: plain code's session, w134/plain.jl) with this directory's lib.sh, for the settings
# SETTINGS (default "G H": W-167's library and the freeze's, the same hour), and vanilla's session as the baseline.
# Cells per run: V none; per setting none, first (the library loaded first), late (loaded after the plain work).
# Interleaved; a warm-up and RUNS runs.
#     bash g4_plain.sh <label> [RUNS=3]       -> logs/g4-plain-<label>.log
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; RUNS=${2:-3}; SETTINGS=${SETTINGS:-G H}
CSV=$R/experiments/interfaces/App/data/sample.csv
header "$LOGS/g4-plain-$label.log" "W-167 E-515 plain code's session (w134/plain.jl)" V $SETTINGS
declare -A E
check V; E[V.up]=$(envfor V "$IMPL/w134/env_up" up) || exit 1; preflight V "${E[V.up]}" CSV DataFrames
for s in $SETTINGS; do check $s
  E[$s.up]=$(envfor $s "$IMPL/w134/env_up" up) || exit 1; preflight $s "${E[$s.up]}" CSV DataFrames
  E[$s.lib]=$(envfor $s "$IMPL/w134/env_lib" lib) || exit 1; preflight $s "${E[$s.lib]}" CSV DataFrames TraitWorld; done
for i in w $(seq "$RUNS"); do
  CUT=300 HEAD=12 cell "V none run $i" jl V --project="${E[V.up]}" "$IMPL/w134/plain.jl" "$CSV" none || true
  for s in $SETTINGS; do CUT=300 HEAD=12 cell "$s none run $i" jl $s --project="${E[$s.up]}" "$IMPL/w134/plain.jl" "$CSV" none || true; done
  for m in first late; do for s in $SETTINGS; do
    CUT=300 HEAD=24 cell "$s $m run $i" jl $s --project="${E[$s.lib]}" "$IMPL/w134/plain.jl" "$CSV" $m || true
  done; done
done
footer
