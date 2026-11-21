#!/bin/bash
# W-159, G-1: E-392 (E-376's harness): what nine unrelated loads cost upstream CSV and DataFrames compiled plainly
# (env_up, the plain baseline on the same build), by facts with one line per module (env_facts), and the forks
# (env_forks); orders A (the work, the loads, the work again) and B (the loads, then the work). The harness:
# w134/lost.jl, unchanged. H and B interleaved per run; a warm-up and RUNS fresh processes per cell.
#     bash g1_loads.sh <label> [RUNS=2]      SETTINGS="H B" ENVS="up facts forks" ORDERS="A B"
# -> logs/g1-loads-<label>.log. About 7 minutes (the tag's round: 18 cells in 3.5 minutes per setting).
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; RUNS=${2:-2}; SETTINGS=${SETTINGS:-H B}
CSV=$R/experiments/interfaces/App/data/sample.csv
LOADS="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"
header "$LOGS/g1-loads-$label.log" "G-1 E-392 nine unrelated loads (w134/lost.jl)" $SETTINGS
declare -A E
for s in $SETTINGS; do check $s
  for e in ${ENVS:-up facts forks}; do E[$s.$e]=$(envfor $s "$IMPL/w134/env_$e" $e) || exit 1
    preflight $s "${E[$s.$e]}" CSV DataFrames $LOADS; done; done
for i in w $(seq "$RUNS"); do
  for e in ${ENVS:-up facts forks}; do for o in ${ORDERS:-A B}; do for s in $SETTINGS; do
    CUT=1500 HEAD=40 cell "$s $e $o run $i" jl $s --project="${E[$s.$e]}" "$IMPL/w134/lost.jl" $o "$CSV" $LOADS || true
  done; done; done
done
footer
