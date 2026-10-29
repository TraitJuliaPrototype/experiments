#!/bin/bash
# U6 (E-252): what each probing module saw when its code ran, per arrangement and precompile mode
# (from logs/<R>-<mode>.log; first session of each run; `none` = no images, the body ran in the session).
cd "$(dirname "$0")"
printf "%-5s %-8s" R probe; for m in parallel serial require compilecache none; do printf " %-12s" $m; done; echo
for R in R1 R2 R3 R4 R5 R6 R7 R8 R8b R9 R9b R10; do
  for p in $(grep -ho "probe=[A-Za-z]*" logs/$R-parallel.log | sort -u | cut -d= -f2); do
    printf "%-5s %-8s" $R $p
    for m in parallel serial require compilecache none; do
      f=logs/$R-$m.log; v=$( [ -f $f ] && grep -m1 "probe=$p seen=" $f | sed 's/.*seen=\([a-z]*\).*/\1/' )
      printf " %-12s" "${v:--}"
    done; echo
  done
done
