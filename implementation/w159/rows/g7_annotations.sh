#!/bin/bash
# W-159, G-7: the annotations per port, against stage 1's baseline (the tag), read from git (no Julia session is
# timed): w156/counts.sh (casts, module options, boxes, wrappers, @default_dynamic, unwrap per demonstrator) at the tag
# and at REV (default `unified`; the freeze tag once it exists); w151/count/annotations.jl for NetworkDynamics; and two
# kinds the head's ports write that neither tool counts: `@implement Callable` (a callable struct declared a member,
# GT-32) and `@nospecializeinfer` at a door (E-506). Code lines of .jl files, comment lines left out.
#     bash g7_annotations.sh <label> [REV=unified]     -> logs/g7-annotations-<label>.log. Under a minute.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; REV=${2:-unified}; TAG=prototype-2026-11
LOG=$LOGS/g7-annotations-$label.log
{ echo "# W-159 G-7 annotations per port | $(date -Is) | load $(load) | the tag $TAG against $REV | experiments $(rev "$R/experiments")"
  bash "$IMPL/w156/counts.sh" $TAG; echo
  echo "# at $REV every compiled_for( is the library's wrapper (WRAPPER=all)"; WRAPPER=all bash "$IMPL/w156/counts.sh" $REV; echo
  for rv in $TAG $REV; do "$(jbin V)" --startup-file=no "$IMPL/w151/count/annotations.jl" "$R/ndport/pkgs/NetworkDynamics-unified" $rv src | sed -n 1,4p; echo; done
  echo "| demonstrator | rev | @implement Callable | @nospecializeinfer |"; echo "|---|---|---|---|"
  for spec in "TraitTables src test" "TraitCSV src ext test" "TraitReport src scripts" "TraitMakie src test scripts compat" \
              "forks Tables/src CSV/src DataFrames/src" "TraitDifferentialEquations src lib test examples" "ndport/pkgs/NetworkDynamics-unified src"; do
    set -- $spec; repo=$1; shift
    for rv in $TAG $REV; do c=0; n=0
      for f in $(git -C "$R/$repo" ls-tree -r --name-only $rv -- "$@" | grep '\.jl$'); do
        txt=$(git -C "$R/$repo" show "$rv:$f" | grep -vE '^\s*#')
        c=$((c + $(echo "$txt" | grep -cE '@implement\s+(TraitWorld\.)?Callable\b'))); n=$((n + $(echo "$txt" | grep -c '@nospecializeinfer')))
      done
      echo "| $repo | $rv ($(git -C "$R/$repo" rev-parse --short "$rv^{commit}")) | $c | $n |"; done; done
  echo "# done $(date -Is)"; } > "$LOG" 2>&1
