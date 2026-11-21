#!/bin/bash
# W-159, G-6: E-384: the small programs (w139/apps): each in a session, `fully_typed(main, (Vector{String},))` there
# (the check of w142/agree.sh), a build under --trim=safe (w166/build_app.sh), the binary run and its output compared
# with the session's. The plain programs (typed_plain, vector_plain, ft_plain_hole) are the baseline on the same build;
# vanilla's refusal of the plain loop is E-383's.
#     bash g6_small.sh <label>       -> logs/g6-small-<label>.log, logs/g6-<label>/. About 8 minutes on H.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; SETTINGS=${SETTINGS:-H}; D=$LOGS/g6-$label; mkdir -p "$D"; W=$IMPL/w139
APPS=${APPS:-typed_trait typed_plain vector_trait vector_plain dynamic_trait family_trait barrier_trait ft_union ft_abstract_result ft_plain_hole ft_any_call ft_abstract_member ft_many_members}
header "$LOGS/g6-small-$label.log" "G-6 E-384 the small programs: session check, build, run (w139/apps)" $SETTINGS
for s in $SETTINGS; do check $s; P=$(tree $s TW); preflight $s "$P" TraitWorld
  for app in $APPS; do
    ses=$(TO=300 jl $s --project="$P" -e 'using TraitWorld; include(ARGS[1])
      r = try fully_typed(main, (Vector{String},)) catch e; e end
      print("\nVERDICT ", r isa Exception ? "the report failed: $(typeof(r))" : isfullytyped(r) ? "fully typed" : "not: $(length(r.sites)) sites", "\n")' "$W/apps/$app.jl" 2>&1 | grep '^VERDICT ' | head -1 | cut -c9-)
    run=$(TO=300 jl $s --project="$P" -e 'include(ARGS[1]); exit(main(String[]))' "$W/apps/$app.jl" 2>&1)
    TRIM=safe DEPOT=$(depot $s) LOGDIR=$D OUTDIR=$D/out bash "$IMPL/w166/build_app.sh" "$(realpath --relative-to="$R" "$(jtree $s)")" "$W/apps/$app.jl" "$s-small-$app" "$P" > /dev/null 2>&1
    bin=-; same=-
    if [ -x "$D/out/$s-small-$app" ]; then b=$(timeout 60 "$D/out/$s-small-$app" 2>&1); bin=$?; [ "$b" = "$run" ] && same=yes || same=no; rm -f "$D/out/$s-small-$app"; fi
    agree=$({ [ "$ses" = "fully typed" ] && [ "$bin" != - ]; } || { [ "$ses" != "fully typed" ] && [ "$bin" = - ]; } && echo yes || echo NO)
    echo "$s $app | session: $ses | build: $(python3 "$IMPL/w135/summarize.py" "$D/$s-small-$app.build.log" | head -1 | sed 's/^[^:]*: //' | cut -c1-120) | binary exit $bin, output equal $same | agree $agree | load $(load)" >> "$LOG"
  done; done
footer
