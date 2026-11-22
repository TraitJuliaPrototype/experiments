#!/bin/bash
# W-159: the head's copies of W-134's packages compiled by facts. w134/pkgs-facts (made by w134/prep.jl; ignored by
# git) carries the line `@compiler_options facts=true bounded=false no_pirates=false dynamic=false first_seen=true`;
# on the head the options `dynamic` and `first_seen` are gone (an error: unknown option). The head's one line for a
# package compiled by facts as it is: `facts=true bounded=false no_pirates=false` (owner_only off: a module that
# declares only facts; reference facts §2, the porting guide 0.1). The tag keeps w134/pkgs-facts as it is.
#     bash facts_head.sh        -> w159/pkgs-facts-head (ignored by git); lib.sh's envfor maps H's env_facts to it
set -eu
H=$(cd "$(dirname "$0")" && pwd); SRC=$H/../w134/pkgs-facts; DST=$H/pkgs-facts-head
[ -d "$SRC/CSV" ] || { echo "w134/pkgs-facts is missing: run w134/prep.jl"; exit 1; }
rm -rf "$DST"; cp -r "$SRC" "$DST"; chmod -R u+w "$DST"
OLD='Base.Experimental.@compiler_options facts=true bounded=false no_pirates=false dynamic=false first_seen=true   # W-134: the one line added'
NEW='Base.Experimental.@compiler_options facts=true bounded=false no_pirates=false   # W-134: the one line added (W-159: the head'"'"'s options)'
n=0
for f in $(grep -rlF "$OLD" "$DST"); do sed -i "s|$(printf '%s' "$OLD" | sed 's/[.[\*^$|]/\\&/g')|$NEW|" "$f"; n=$((n + 1)); done
echo "lines replaced in $n files; left with the old line: $(grep -rlF "$OLD" "$DST" | wc -l)"
grep -rn "W-159: the head" "$DST" | sed "s|$DST/||"
