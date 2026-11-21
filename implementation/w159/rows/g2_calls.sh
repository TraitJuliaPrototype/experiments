#!/bin/bash
# W-159, G-2: E-374's calls. H runs w159/calls_head.jl (the head's API) in the head library's project; B runs
# w145/calls/calls.jl, E-374's own script, in TraitWorld-base (E-437's pairing). The baseline is the plain twin in
# the same process (plain code on the build); the tag is the regression control. Interleaved, RUNS processes each.
#     bash g2_calls.sh <label> [RUNS=2] [N=10^7]        -> logs/g2-calls-<label>.log. About 4 minutes.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; RUNS=${2:-2}; N=${3:-10000000}; SETTINGS=${SETTINGS:-H B}
header "$LOGS/g2-calls-$label.log" "G-2 E-374 calls (H: w159/calls_head.jl, B: w145/calls/calls.jl), N=$N" $SETTINGS
for s in $SETTINGS; do check $s; preflight $s "$(tree $s TW)" TraitWorld; done
for i in $(seq "$RUNS"); do for s in $SETTINGS; do
  case $s in H) f=$W159/calls_head.jl ;; B) f=$IMPL/w145/calls/calls.jl ;; *) die "calls: setting $s" ;; esac
  TO=900 cell "$s run $i ($(basename $f))" jl $s --project="$(tree $s TW)" "$f" $N || true
done; done
footer
