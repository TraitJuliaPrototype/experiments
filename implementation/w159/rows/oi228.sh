#!/bin/bash
# W-159, open issue 228's first step: which instances the ODE port's images hold at load, on H against B (the tag's
# session does not compile TraitRodas._rodas5_run at the session's integrator; the head's does, 315 ms of the first
# run's 651 ms). Two tools of W-161 (w161/d2): image_instances.jl (every instance with valid code right after loading,
# per function, one line each, sorted) and rodas_image.jl (the one case: `_rodas5_run`'s instances, valid or not).
# Then the lists' difference, and the instance the session compiles (g6_sessions.sh's trace) looked up in each list.
#     bash oi228.sh <label>          -> logs/oi228-<label>.log, logs/oi228-<label>-<S>.txt. About a minute.
# What it decides: "missing at load" (the instance is in neither list on H: not compiled by the workload, or not
# kept by the serializer) against "kept and dropped" (the list of a process that writes the image holds it). The
# second needs the writing process's list: the next step, recorded in the README.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; SETTINGS=${SETTINGS:-H B}
header "$LOGS/oi228-$label.log" "open issue 228: the ODE port's image at load (w161/d2/image_instances.jl, rodas_image.jl)" $SETTINGS
declare -A E
for s in $SETTINGS; do check $s; E[$s]=$(envfor $s "$IMPL/w134/env_demo" demo) || exit 1
  preflight $s "${E[$s]}" TraitWorld TraitDifferentialEquations; done
for s in $SETTINGS; do
  cell "$s image_instances" jl $s --project="${E[$s]}" "$IMPL/w161/d2/image_instances.jl" "$LOGS/oi228-$label-$s.txt" TraitDifferentialEquations ODECore TraitRodas || true
  HEAD=40 cell "$s rodas_image" jl $s --project="${E[$s]}" "$IMPL/w161/d2/rodas_image.jl" || true
  echo "# $s: $(wc -l < "$LOGS/oi228-$label-$s.txt") instances; by function (the eight of the open issue):" >> "$LOG"
  for f in _rodas5_run advance! core_solution run_to_end! _steps _retcode step_condition step_affect!; do
    printf '#   %-16s %s\n' "$f" "$(grep -c "typeof(.*\.$f)" "$LOGS/oi228-$label-$s.txt")" >> "$LOG"; done
done
if [ -f "$LOGS/oi228-$label-H.txt" ] && [ -f "$LOGS/oi228-$label-B.txt" ]; then
  echo "# in B's image, not in H's (by line; the types print alike on both builds):" >> "$LOG"
  comm -13 <(sort "$LOGS/oi228-$label-H.txt") <(sort "$LOGS/oi228-$label-B.txt") | head -60 >> "$LOG"
fi
footer
