#!/bin/bash
# W-170 (E-538): E-537's profile of the steady state (w169/stiff/run.jl, mode profile, classed by its profclass.jl),
# in a setting's environment, for the port and the twin.
#     bash prof.sh <label> "<problem:cb ...>" ["<setting:stack:form ...>"]     -> logs/prof-<label>.log
#     python3 ../w169/stiff/profms.py logs/prof-<label>.log
source "$(cd "$(dirname "$0")" && pwd)/env.sh"
label=$1; cases=$2; CELLS=${3:-"A:port:box A:port:compiled A:plain:wrap A:plain:spec"}
export BRUSS_N=${BRUSS_N:-16} PROF_S=${PROF_S:-8}
LOG=$W/logs/prof-$label.log
header "prof $label: $cases, PROF_S=$PROF_S, BRUSS_N=$BRUSS_N" > "$LOG"
for k in $cases; do for c in $CELLS; do
  prob=${k%%:*}; cb=${k##*:}; IFS=: read -r s st fm <<< "$c"
  echo "== $prob cb$cb $s $st $fm | load $(load)" >> "$LOG"
  out=$(jS "$s" demo "$ST/run.jl" "$st" "$prob" "$cb" "$fm" profile 2>&1); rc=$?
  echo "$out" | grep -q Precompiling && { echo "# FAIL: precompiled" >> "$LOG"; exit 1; }
  echo "$out" | grep -E '^P |ERROR' | sed "s/^P /P $s /" >> "$LOG"
  echo "-- rc $rc | load $(load)" >> "$LOG"
done; done
echo "# done $(date -Is) | load $(load)" >> "$LOG"
