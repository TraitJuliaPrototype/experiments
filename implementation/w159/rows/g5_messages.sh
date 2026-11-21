#!/bin/bash
# W-159, G-5: E-385, E-370's fifteen mistakes (w136/cases, unchanged): each case a fresh process, its output as the
# user sees it. Trait forms on H and B in the library's project, the cases 04a 05 06 again under strict mode; the
# plain forms on vanilla (the baseline) and on the head without the library (the control that the build changes no
# plain message). Then SciML's three cases (w136/sciml/port.jl: the port and its plain twin PlainODE) on H and B.
# The table: w161/d4/summarize.py per directory.
#     bash g5_messages.sh <label>      CASES=<pattern> (default all; SCIML=0 skips SciML)
#                                  -> logs/g5-<label>/<S>/<case>.<form>.out, logs/g5-<label>/<S>/summary.md,
#                                         logs/g5-messages-<label>.log. About 6 minutes.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; SETTINGS=${SETTINGS:-H B}; C=$IMPL/w136; O=$LOGS/g5-$label; STRICT="04a 05 06"
header "$LOGS/g5-messages-$label.log" "G-5 E-385 the fifteen mistakes and SciML's three cases (w136)" $SETTINGS V
for s in $SETTINGS; do check $s; preflight $s "$(tree $s TW)" TraitWorld; done; check V
declare -A E
[ "${SCIML:-1}" = 1 ] && for s in $SETTINGS; do E[$s]=$(envfor $s "$IMPL/w134/env_demo" demo) || exit 1; preflight $s "${E[$s]}" TraitDifferentialEquations PlainODE; done
run() { # run <setting> <out> <project or ""> <file> [VAR=value]
  local s=$1 out=$2 proj=$3 f=$4 v=${5:-}; mkdir -p "$O/$s"
  ( [ -n "$v" ] && export "$v"; TO=300 jl $s --color=no ${proj:+--project=$proj} "$f" ) > "$O/$s/$out.out" 2>&1
  local rc=$?; grep -q Precompiling "$O/$s/$out.out" && die "$s $out precompiled: an image was stale or missing"
  echo "$s $out exit $rc | load $(load)" >> "$LOG"; }
for f in $C/cases/*${CASES:-}*.jl; do
  b=$(basename "$f" .jl); c=${b%.*}; form=${b##*.}; n=${c%%_*}
  if [ "$form" = trait ]; then
    for s in $SETTINGS; do run $s "$c.trait" "$(tree $s TW)" "$f"
      case " $STRICT " in *" $n "*) run $s "$c.trait-strict" "$(tree $s TW)" "$f" JULIA_TW_STRICT=1 ;; esac; done
  else run V "$c.plain" "" "$f"; run H "$c.plain-build" "" "$f"; fi
done
[ "${SCIML:-1}" = 1 ] && for s in $SETTINGS; do for form in trait plain; do
  mkdir -p "$O/$s/sciml"; ( cd "$C/sciml" && export W136_LOGS="$O/$s/sciml" && TO=600 jl $s --color=no --project="${E[$s]}" port.jl $form ) > "$O/$s/sciml-port-$form.txt" 2>&1
  echo "$s sciml $form exit $? | load $(load)" >> "$LOG"; done; done
for s in $SETTINGS V; do python3 "$IMPL/w161/d4/summarize.py" "$O/$s" > "$O/$s/summary.md"; echo "# $s: $O/$s/summary.md" >> "$LOG"; done
footer
