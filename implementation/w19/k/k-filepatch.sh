#!/bin/bash
# A patch of one file against the file as the step's pick leaves it: HEAD's file with the pick's diff of that file
# and the given patches' diffs of it applied. Usage: k-filepatch.sh <pick-sha> <file> [patch...] > out.patch
set -e
K=$(cd $(dirname "$0"); pwd)
f=$2; pick=$1; shift 2
T=$(mktemp -d /tmp/claude-harvest/k-tmp/fp.XXXX); mkdir -p $T/a/$(dirname $f)
git show HEAD:$f > $T/a/$f
git diff $pick^ $pick -- $f > $T/pick.patch
(cd $T/a && { [ ! -s ../pick.patch ] || git apply ../pick.patch; } && for p in "$@"; do git apply --include=$f $K/patches/$p; done)
cp $f $T/new
(cd $T && diff -u a/$f new | sed "1s|.*|--- a/$f|;2s|.*|+++ b/$f|" > out.diff) || true
echo "diff --git a/$f b/$f"; cat $T/out.diff
rm -rf $T
