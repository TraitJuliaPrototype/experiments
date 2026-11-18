#!/bin/bash
# W-155b (open issue 189's pattern): a runtime object reachable only from a pointer the collector does not
# see. Lists each global the trait code declares JL_GLOBALLY_ROOTED (an annotation for the analyzer, which
# the stock collector does not read) that neither gc-stock.c's root list nor a system-image list names.
#     bash roots.sh <julia tree>
T=${1:-$(cd "$(dirname "$0")/../../../.." && pwd)/julia-s3}
for f in datatype.c gf.c subtype.c builtins.c; do
  # a function's prototype carries the annotation for its result: not a global
  grep -n "JL_GLOBALLY_ROOTED" "$T/src/$f" | grep -v "extern\|^.*//.*JL_GLOBALLY_ROOTED is\|(" | while IFS= read -r line; do
    name=$(echo "$line" | sed -E 's/.*[ *]([A-Za-z_][A-Za-z0-9_]*)(\[[^]]*\])? +JL_GLOBALLY_ROOTED.*/\1/')
    if grep -q "\b$name\b" "$T/src/gc-stock.c"; then s="rooted"; elif grep -q "\b$name\b" "$T/src/staticdata.c"; then s="in the image's lists"
    elif [ "$name" = jl_implements_ft ]; then s="reachable: the type of Core's constant binding implements"; else s="NOT ROOTED"; fi
    echo "$s | $f: $name"
  done
done | sort
