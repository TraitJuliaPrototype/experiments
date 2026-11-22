#!/bin/bash
# W-168, open issue 257: the gates that read a CodeInstance's flag bit themselves, each run as it is (the control, it
# must pass on the head) and with its two masks swapped, 0x10 (G2) and 0x20 (facts) exchanged in a copy (the mutation:
# a gate that reads the wrong bit must fail; one that still passes does not discriminate). One Julia job at a time.
#     bash oi257_gates.sh <label>       -> logs/oi257-gates-<label>.log. About 4 minutes.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; header "$LOGS/oi257-gates-$label.log" "open issue 257: the gates that read flag bits, as they are and with the masks swapped" H
check H
G=$IMPL/gates; T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
# name | path | project
while IFS='|' read -r name path proj; do
  [ -z "$name" ] && continue
  d=$T/$name; mkdir -p "$d"; cp "$G/util.jl" "$d/"; cp "$IMPL/$path" "$d/gate.jl"
  python3 - "$d/gate.jl" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
s=s.replace("0x10","@@A@@").replace("0x20","0x10").replace("@@A@@","0x20")
open(p,"w").write(s)
PY
  case $proj in TraitWorld) pa="--project=$(tree H TW)" ;; stub) pa="--project=$IMPL" ;; *) pa="" ;; esac
  for v in control mutant; do
    f=$IMPL/$path; [ $v = mutant ] && f=$d/gate.jl
    [ $v = control ] && { cp "$IMPL/$path" "$d/control.jl"; f=$d/control.jl; }
    out=$(cd "$d" && TO=900 jl H $pa "$f" 2>&1 < /dev/null); rc=$?
    echo "$name | $v | exit $rc | $(echo "$out" | grep -v '^ *$' | tail -1 | cut -c1-200) | load $(load)" >> "$LOG"
    [ $v = mutant ] && [ $rc != 0 ] && echo "$out" | grep -m2 -E "AssertionError|Error" | cut -c1-200 | sed 's/^/    /' >> "$LOG"
  done
done <<'LIST'
f3_policy_code|gates/f3_policy_code.jl|stub
f4_g2_bit|gates/f4_g2_bit.jl|stub
f6_reach_policy|gates/f6_reach_policy.jl|stub
n15_image_policy|gates/n15_image_policy.jl|stub
n17_rtsite_targets|gates/n17_rtsite_targets.jl|stub
n21_callsig_backedge|gates/n21_callsig_backedge.jl|stub
n26_callable_late_method|gates/n26_callable_late_method.jl|TraitWorld
n34_closed_invoke_compiled|gates/n34_closed_invoke_compiled.jl|stub
w155_gate_deep|w155/gate_deep.jl|none
LIST
footer
