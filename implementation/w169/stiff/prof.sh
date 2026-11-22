#!/bin/bash
# E-537 §3: the steady state profiled (run.jl, mode profile: PROF_S seconds of solves after two warm-up solves, the
# sampling profiler at 0.5 ms with C frames, the samples classed by profclass.jl), for the port and the twin.
#     bash prof.sh <label> "<problem:cb ...>" ["<stack:form ...>"]     -> logs/prof-<label>.log
source "$(cd "$(dirname "$0")" && pwd)/env.sh"
label=$1; cases=$2; CELLS=${3:-"port:box port:compiled plain:wrap plain:spec"}
export BRUSS_N=${BRUSS_N:-16} PROF_S=${PROF_S:-8}
LOG=$S/logs/prof-$label.log
header "prof $label: $cases, PROF_S=$PROF_S, BRUSS_N=$BRUSS_N" > "$LOG"
for k in $cases; do for c in $CELLS; do
  prob=${k%%:*}; cb=${k##*:}; st=${c%%:*}; fm=${c##*:}
  echo "== $prob cb$cb $st $fm | load $(load)" >> "$LOG"
  out=$(jS "$st" "$S/run.jl" "$st" "$prob" "$cb" "$fm" profile 2>&1); rc=$?
  echo "$out" | grep -q Precompiling && { echo "# FAIL: precompiled" >> "$LOG"; exit 1; }
  echo "$out" | grep -E '^P |ERROR' >> "$LOG"
  echo "-- rc $rc | load $(load)" >> "$LOG"
done; done
echo "# done $(date -Is) | load $(load)" >> "$LOG"
