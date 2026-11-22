#!/bin/bash
# W-170 (E-538): E-536's session cells, interleaved: per round each cell once (bash session.sh <cell> time <round>);
# a warm-up round first, not counted (run 0).
#     CELLS="odecb:A odecb-plain:A" bash sessions.sh <label> [P=3]   -> logs/sessions/<label>-<session>-<S>-time-<r>.out
source "$(cd "$(dirname "$0")" && pwd)/env.sh"
label=$1; P=${2:-3}
for r in $(seq 0 "$P"); do for c in ${CELLS:-odecb:A odecb-plain:A}; do
  ses=${c%%:*}; s=${c##*:}
  bash "$W/session.sh" "$ses" "$s" time "$label-$r" || exit $?
done; done
