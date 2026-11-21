#!/bin/bash
# W-159, step 0 of the round: the tag's trees that the regression control (setting B) needs and that do not exist yet.
# Worktrees detached at `prototype-2026-11`, under wt/w159-tag/ (the design repository ignores wt/). Each adds a
# worktree to the demonstrator's repository and changes no branch. Run by the main session; the agent that wrote this
# did not run it (the demonstrators' repositories were read only for it).
#     bash trees.sh            # makes what is missing, then lists every tree of B with its commit
#     bash trees.sh --list     # lists only
set -u
R=$(cd "$(dirname "$0")/../../../.." && pwd); T=$R/wt/w159-tag
if [ "${1:-}" != --list ]; then
  mkdir -p "$T"
  for r in TraitTables TraitCSV TraitReport forks; do
    [ -d "$T/$r" ] || git -C "$R/$r" worktree add --detach "$T/$r" prototype-2026-11 || exit 1
  done
fi
for t in julia-unified TraitWorld-base wt/w161-tde-base wt/w160-tm wt/w151-base/NetworkDynamics \
         wt/w159-tag/TraitTables wt/w159-tag/TraitCSV wt/w159-tag/TraitReport wt/w159-tag/forks; do
  if [ -d "$R/$t" ]; then
    printf '%-34s %s %s\n' "$t" "$(git -C "$R/$t" rev-parse --short=10 HEAD)" \
      "$([ "$(git -C "$R/$t" rev-parse HEAD)" = "$(git -C "$R/$t" rev-parse 'prototype-2026-11^{commit}')" ] && echo "= the tag" || echo "NOT THE TAG")"
  else printf '%-34s absent\n' "$t"; fi
done
