#!/bin/bash
# W-142 (traits T-109): does the session's fully typed check agree with the closed build? For each small
# program of ../w139/apps: `fully_typed(main, (Vector{String},))` in a session, and a build under
# --trim=safe. Writes logs/agree[-tag].log. bash agree.sh [tag] [apps…]
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
tag=${1:+-$1}; shift 2>/dev/null
apps=${*:-typed_trait typed_plain vector_trait vector_plain dynamic_trait family_trait barrier_trait ft_union ft_abstract_result ft_plain_hole ft_any_call ft_abstract_member ft_many_members}
LOG=$H/logs/agree$tag.log
rev() { git -C "$R/$1" log -1 --format=%h; }
echo "# W-142 $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified $(rev julia-unified) TraitWorld-unified $(rev TraitWorld-unified)" > "$LOG"
printf "%-22s | %-34s | %-22s | %s\n" program "the session's check" "the build" agree | tee -a "$LOG"
for app in $apps; do
  ses=$(cd "$R/TraitWorld-unified" && JULIA_PKG_OFFLINE=true nice -n 10 "$R/julia-unified/julia" -t 1 --startup-file=no --project=. -e '
    using TraitWorld
    include(ARGS[1])
    r = try fully_typed(main, (Vector{String},)) catch e; e end
    if r isa Exception
        print("\nVERDICT the report failed: ", typeof(r), "\n")
    else
        print("\nVERDICT ", isfullytyped(r) ? "fully typed" : string("not: ", length(r.sites), " sites"), "\n")
    end' "$H/../w139/apps/$app.jl" 2>&1 | grep "^VERDICT " | head -1 | sed "s/^VERDICT //")
  NAME=w142-$app TRIM=safe bash "$H/../w139/build.sh" $app > /dev/null 2>&1; rc=$?
  errs=$(grep -o "Trim verify finished with [0-9]* errors" "$H/../w139/logs/w142-$app.build.log" | grep -o "[0-9]*" | head -1)
  bld=$([ $rc -eq 0 ] && echo "builds" || echo "refused: ${errs:-?} errors")
  s1=$([ "$ses" = "fully typed" ] && echo y || echo n); s2=$([ $rc -eq 0 ] && echo y || echo n)
  printf "%-22s | %-34s | %-22s | %s\n" "$app" "$ses" "$bld" "$([ $s1 = $s2 ] && echo yes || echo NO)" | tee -a "$LOG"
done
