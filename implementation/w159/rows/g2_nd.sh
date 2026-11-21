#!/bin/bash
# W-159, G-2: NetworkDynamics' workload (ndport/scripts/workload.jl; NDW_API=ports NDW_STACK=ports; passes first,
# again, params, changed, graphtype), E-438's pairing: H and B interleaved, a warm-up and RUNS sessions each; the
# digests compared (ndport/scripts/compare_digests.py, H against B). The steady state is the pass `again`.
# UPSTREAM=1 adds upstream's packages on vanilla (ndport/env_upstream, the workload's default API) as a reference:
# a different solver stack (SciML), so not a twin of the port: its numbers are stated beside, not compared as a
# baseline of the same code (the playbook's "settings that differ in several things at once").
#     bash g2_nd.sh <label> [RUNS=2]      -> logs/g2-nd-<label>.log, logs/g2-nd-<label>-<S>-<i>.out
# About 5 minutes (43-45 s a session), 8 with UPSTREAM=1.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; RUNS=${2:-2}; SETTINGS=${SETTINGS:-H B}
header "$LOGS/g2-nd-$label.log" "G-2 NetworkDynamics' workload (ndport/scripts/workload.jl)" $SETTINGS ${UPSTREAM:+V}
echo "# ndport $(rev $R/ndport) (the workload's scripts, the same for every setting) GraphMakie $(rev $R/ndport/pkgs/GraphMakie-unified) Graphs $(rev $R/ndport/pkgs/Graphs-unified)" >> "$LOG"
declare -A E
for s in $SETTINGS; do check $s; E[$s]=$(envfor $s "$R/ndport/env_unified_r5" nd) || exit 1
  preflight $s "${E[$s]}" NetworkDynamics TraitDifferentialEquations MakieCompat GraphMakie; done
[ -n "${UPSTREAM:-}" ] && { check V; E[V]=$(envfor V "$R/ndport/env_upstream" ndup) || exit 1; preflight V "${E[V]}" NetworkDynamics OrdinaryDiffEqTsit5 CairoMakie GraphMakie; }
for i in $(seq 0 "$RUNS"); do for s in $SETTINGS ${UPSTREAM:+V}; do
  out="$LOGS/g2-nd-$label-$s-$i.out"; t0=$(date +%s.%N)
  ( cd "$R/ndport"
    if [ $s = V ]; then export NDW_PASSES=first,again,params,changed; else export NDW_API=ports NDW_STACK=ports NDW_PASSES=first,again,params,changed,graphtype; fi
    TO=1500 jl $s --project="${E[$s]}" scripts/workload.jl ) > "$out" 2>&1; rc=$?
  grep -q Precompiling "$out" && die "$s run $i precompiled: an image was stale or missing"
  echo "== $s run $i (0: the warm-up) | rc $rc | session $(echo "$(date +%s.%N) - $t0" | bc | cut -c1-6) s | load $(load) | $(grep '^W total' "$out" | head -1) | T again: $(grep '^T again' "$out" | awk '{s+=$4} END {print s " ms"}')" >> "$LOG"
done; done
for i in $(seq 1 "$RUNS"); do
  echo "# digests H run $i against B run $i:" >> "$LOG"
  python3 "$R/ndport/scripts/compare_digests.py" "$LOGS/g2-nd-$label-B-$i.out" "$LOGS/g2-nd-$label-H-$i.out" 2>&1 | tail -3 >> "$LOG"
done
footer
