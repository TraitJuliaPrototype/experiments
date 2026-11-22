#!/bin/bash
# The library's load, before (unified 57879c3) and after (w150): for each, the image built at its first load (not
# timed), then a warm-up and 3 runs, each a fresh process timing `using TraitWorld` in milliseconds. The worktree is
# checked out at each revision in turn and left at `w150`. Source env.sh and set the depot first (README.md).
set -e
R=/p/projects/coen/julia-trait-bound
W=$R/wt/w158g-tw
J=$R/julia-next/julia
revs=${REVS:-"57879c3 w150"}
for rev in $revs; do
  git -C "$W" checkout -q "$rev"
  echo "== $rev ($(git -C "$W" rev-parse --short HEAD)), load $(cut -d' ' -f1-3 /proc/loadavg)"
  nice "$J" --startup-file=no --project="$W" -e 'using TraitWorld' > /dev/null
  for i in warmup 1 2 3; do
    t=$(nice "$J" --startup-file=no --project="$W" -e 't = @elapsed using TraitWorld; print(round(t * 1000; digits = 1))')
    echo "$i $t"
  done
done
git -C "$W" checkout -q w150
