#!/bin/bash
# W-159, open issue 225: plain code's first work on `next` (3.31-3.47 s, E-499) against the tag's (2.90-3.00 s),
# bisected over next's first-parent commits, one build at a time (sustained use: WIDE=0, about 14 minutes a build).
# The measure: w134/plain.jl `none` in W-134's env_up (upstream CSV and DataFrames compiled plainly), a warm-up and 3
# runs of the commit's build, interleaved with 3 of the tag's (julia-unified) and 3 of vanilla's in the same hour.
# The verdict, by the medians of the first work: bad if the commit's exceeds the tag's by more than 0.20 s, good if by
# less than 0.10 s, else two more runs of each, then bad above 0.15 s. (E-499's gap is 0.31 to 0.57 s; its runs spread
# 0.10 to 0.16 s.)
#   bash oi225.sh setup                    a julia worktree wt/w159-bisect (detached), deps/srccache copied from julia-next
#   bash oi225.sh step <commit>            checkout, build, the images of CSV and DataFrames, the measure; exit 0 good,
#                                          1 bad, 125 the commit does not build (git bisect run's codes)
#   bash oi225.sh run                      git bisect over next's first parents, tag good, next bad, each step `step`
# Logs: logs/oi225-<commit>.log; the build's log in the tree (tw-build.log).
# Prior (the order of the first steps): E-479 measured next-s3 bc844be7c0, a branch from 9b6dacf5c5, at 3.36 s;
# so `step 9b6dacf5c5` first: bad leaves 7063158f42, 3037289af6, 9b6dacf5c5 (2 more builds); good leaves the 24
# first-parent commits after it (5 more; a merge found bad bisects its 11 side commits, 4 more).
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
BT=$R/wt/w159-bisect; GOOD=7b374f39ce; BAD=${BAD:-$(git -C "$R/julia-next" rev-parse --short=10 HEAD)}
CSV=$R/experiments/interfaces/App/data/sample.csv
case ${1:-} in
setup)
  [ -d "$BT" ] || git -C "$R/julia-1.13" worktree add --detach "$BT" $GOOD || exit 1
  mkdir -p "$BT/deps/srccache"; cp -rn "$R/julia-next/deps/srccache/." "$BT/deps/srccache/"
  echo "worktree $BT at $(git -C "$BT" rev-parse --short=10 HEAD); the first build makes the dependencies (longer than a step)" ;;
step)
  c=$(git -C "$BT" rev-parse --short=10 "$2") || exit 125
  git -C "$BT" checkout --detach -q "$c" || exit 125
  WIDE=0 bash "$R/tools-local/build.sh" "$BT" > /dev/null 2>&1
  tail -1 "$BT/tw-build.log" | grep -q 'BUILD EXIT 0' || { echo "$c: build failed"; exit 125; }
  DIE_CODE=125; X_JULIA=$BT     # setting X: the commit's build, its own depot; the tag's trees for the rest
  depot() { [ "$1" = X ] && echo "$W159_DEPOTS/oi225-$c" || echo "$W159_DEPOTS/$1"; }
  X_TW=TraitWorld-base X_TDE=$B_TDE X_TM=$B_TM X_TT=$B_TT X_TC=$B_TC X_TR=$B_TR X_FORKS=$B_FORKS X_ND=$B_ND
  header "$LOGS/oi225-$c.log" "open issue 225: plain code's first work, $c against the tag and vanilla (w134/plain.jl none)" X B V
  for s in X B V; do check $s; done
  EX=$(envfor X "$IMPL/w134/env_up" up) || exit 125; EB=$(envfor B "$IMPL/w134/env_up" up) || exit 1; EV=$(envfor V "$IMPL/w134/env_up" up) || exit 1
  ALLOW_PRECOMPILE=1 TO=3600 HEAD=5 cell "images X" jl X --project="$EX" -e 'Base.Precompilation.precompilepkgs(["CSV", "DataFrames"]; timing = true)' || exit 125
  preflight X "$EX" CSV DataFrames; preflight B "$EB" CSV DataFrames; preflight V "$EV" CSV DataFrames
  med() { grep -h "^== $1 run [0-9]" -A3 "$LOG" | grep -o 'first work [0-9.]*' | awk '{print $3/1000}' | sort -n | awk '{a[NR]=$1} END {print (NR%2 ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2)}'; }
  rounds() { for i in "$@"; do for s in X B V; do e=$EX; [ $s = B ] && e=$EB; [ $s = V ] && e=$EV
    CUT=300 HEAD=6 cell "$s run $i" jl $s --project="$e" "$IMPL/w134/plain.jl" "$CSV" none || true; done; done; }
  rounds w 1 2 3
  d=$(awk -v x="$(med X)" -v b="$(med B)" 'BEGIN{print x-b}')
  if awk -v d="$d" 'BEGIN{exit !(d > 0.10 && d < 0.20)}'; then rounds 4 5; d=$(awk -v x="$(med X)" -v b="$(med B)" 'BEGIN{print x-b}'); lim=0.15; else lim=0.15; fi
  v=$(awk -v d="$d" -v l=$lim 'BEGIN{print (d > l ? "bad" : "good")}')
  echo "# verdict $c: $v (median first work X $(med X) s, the tag $(med B) s, vanilla $(med V) s; difference $d s)" >> "$LOG"; footer
  echo "$c $v $d"; [ $v = good ] ;;
run)
  git -C "$BT" bisect start --first-parent "$BAD" "$GOOD" && git -C "$BT" bisect run bash "$0" step HEAD
  git -C "$BT" bisect log > "$LOGS/oi225-bisect.log"; git -C "$BT" bisect reset ;;
*) sed -n 2,22p "$0"; exit 2 ;;
esac
