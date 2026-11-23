#!/bin/bash
# The tree a step's patch applies to: HEAD with the step's pick and the patches before it (k-restack.py's order),
# in a scratch index. Prints the tree's id. Usage: k-basetree.sh <pick-sha> [patch...]
set -e
K=$(dirname "$0")
export GIT_INDEX_FILE=$(mktemp -u /tmp/claude-harvest/k-tmp/idx.XXXX)
git read-tree HEAD
git diff "$1^" "$1" | git apply --cached -3 >/dev/null 2>&1 || { echo "pick did not apply" >&2; exit 1; }
shift
for p in "$@"; do git apply --cached -3 "$K/patches/$p" >/dev/null 2>&1 || { echo "patch $p did not apply" >&2; exit 1; }; done
git write-tree
rm -f "$GIT_INDEX_FILE"
