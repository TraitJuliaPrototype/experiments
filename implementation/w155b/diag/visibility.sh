#!/bin/bash
# W-155b (E-459's first failure): a change of a membership entry's worlds that does not raise the runtime's
# latest change (`jl_membership_changed`). A match's range of worlds is taken without a walk at a query in
# that world or later (subtype.c, `jl_membership_world_range`); a change it does not know of makes a cached
# dispatch span the change, so a task in an older world, or the latest one, takes the other's method.
# Lists each function of the runtime that writes an entry's `min_world` or `max_world` (a function that
# names `jl_membership_t`), and whether it raises the change itself or through `publish_entry`. The image's
# writer (staticdata.c) writes copies, which change no world of the session: listed apart.
#     bash visibility.sh [julia tree]
T=${1:-$(cd "$(dirname "$0")/../../../.." && pwd)/julia-s3}
for f in datatype.c gf.c staticdata.c; do
  awk -v file="$f" '
    /^[A-Za-z_].*\(/ && !/;[ \t]*$/ { if (fn != "" && writes && memb) report(); fn = $0; sub(/\(.*/, "", fn); n = split(fn, a, /[ *]+/); fn = a[n]; writes = 0; memb = 0; raises = 0 }
    /jl_membership_t/ { memb = 1 }
    /(en|entry|found|o|ne)->min_world *=|atomic_store[a-z_]*\(&(en|entry|found|o|ne)->max_world/ { writes = 1 }
    /jl_membership_changed\(|publish_entry\(/ { raises = 1 }
    function report() { printf "%s | %s: %s\n", (file == "staticdata.c" ? "a copy for an image" : raises ? "raises the change" : "DOES NOT RAISE IT"), file, fn }
    END { if (fn != "" && writes && memb) report() }
  ' "$T/src/$f"
done
