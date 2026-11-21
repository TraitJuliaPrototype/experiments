#!/bin/bash
# W-159, G-4: an image's size and build time. Each package's image written anew (w159/image_build.jl, Base.compilecache
# into a scratch depot stacked first, removed after), on H and on B, RUNS times: the library, the trait packages and
# their plain twins (the baseline: plain code on the build; E-380's comparison). Then the system images' sizes and
# the build's stages from each Julia tree's tw-build.log (the build time of Julia itself, against vanilla's log where
# it exists; E-262's comparison).
#     bash g4_images.sh <label> [RUNS=1]      PKGS="..."   -> logs/g4-images-<label>.log. About 8 minutes.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; RUNS=${2:-1}; SETTINGS=${SETTINGS:-H B}
PKGS=${PKGS:-TraitWorld TraitTables TraitCSV PlainTables TraitDifferentialEquations PlainODE TraitMakie PlainPlots}
header "$LOGS/g4-images-$label.log" "G-4 images: size and build time (w159/image_build.jl)" $SETTINGS V
declare -A E
for s in $SETTINGS; do check $s; E[$s]=$(envfor $s "$IMPL/w134/env_demo" demo) || exit 1; preflight $s "${E[$s]}" $PKGS; done
for i in $(seq "$RUNS"); do for s in $SETTINGS; do
  X=$(depot $s)-images-scratch; rm -rf "$X"; mkdir -p "$X"
  XDEPOT=$X TO=3600 cell "$s run $i" jl $s --project="${E[$s]}" "$W159/image_build.jl" $PKGS || true
  rm -rf "$X"
done; done
for s in $SETTINGS V; do jt=$(jtree $s)
  echo "# $s $(basename $jt): sys.so $(stat -c %s $jt/usr/lib/julia/sys.so) bytes | build log: $( [ -f $jt/tw-build.log ] && { head -1 $jt/tw-build.log | cut -c1-120; grep -E 'Compiling the compiler|Base  *─|sysimg|BUILD EXIT' $jt/tw-build.log | cut -c1-80 | tr '\n' ';'; } || echo none)" >> "$LOG"
done
footer
