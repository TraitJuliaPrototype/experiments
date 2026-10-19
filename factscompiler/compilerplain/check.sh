#!/bin/bash
# Whether the compiler's own code runs plainly: the dynamic calls made from frames in
# Compiler/src while new code compiles (the dispatch profiler's call sites), plain and under the
# facts image. Plain code makes some (Julia's compiler has `@nospecialize` helpers it calls
# dynamically); the facts image should make the same number, not more.
J13=/home/hellmann/Repos/julia-trait-bound/julia-1.13
cd "$(dirname "$0")"
for m in plain all; do
  if [ $m = all ]; then A="-J $J13/usr/lib/julia/facts/sys.so"; D="${TMPDIR:-/tmp}/depot-facts:$HOME/.julia:"; else A=""; D=""; fi
  out=$(env ${D:+JULIA_DEPOT_PATH=$D} JULIA_FACTS_DISPATCH_PROFILE=1 $J13/julia $A --startup-file=no work.jl 2>&1)
  comp=$(echo "$out" | awk '/by call site/{f=1;next} f && /Compiler\/src/ {s+=$1} END{print s+0}')
  all=$(echo "$out" | awk '/by call site/{f=1;next} f && NF {s+=$1} END{print s+0}')
  echo "$m: $(echo "$out" | grep 'compile work'); dynamic calls at the top 40 sites $all, of them from Compiler/src $comp"
done
