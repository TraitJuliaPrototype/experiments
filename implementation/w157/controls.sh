#!/bin/bash
# W-157 (E-478's control, E-479, E-480): on the head and on the baseline's system image (213c759370, kept
# before the first rebuild; the runtime is the same), one after another, alternating:
#   the work after the nine loads (W-134's lost.jl, runs.sh), plain code's first work (W-134's plain.jl,
#   upstream CSV and DataFrames), Base's `precompile` test; then P6's count on the head (w152/p6/split.jl).
#     bash controls.sh <label>
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; cd "$H"
L=$1; BASE="-J $TW_ROOT/.julia-depot/agent-depots/w157-baseline/sys-213c759370.so"
P=logs/$L-plain.log
echo "# $L $(date -Is) | julia-s3 $(git -C $TW_ROOT/julia-s3 log -1 --format=%h) | load $(cut -d' ' -f1-3 /proc/loadavg)" > logs/$L-controls.log
# the images of the plain environment and the baseline's of the others
for jf in "" "$BASE"; do
  for e in env_up env_forks env_facts env_session; do
    JULIA_NUM_PRECOMPILE_TASKS=4 nice -n 10 $JS $jf --startup-file=no --project=$e -e 'using Pkg; Pkg.precompile()' >> logs/$L-precompile.log 2>&1
  done
done
echo "images done $(date -Is)" >> logs/$L-controls.log
# the census on the baseline's image: the copies P3's demand rule would make there (E-476's table)
for e in env_forks env_facts; do
  nice -n 10 $JS $BASE --startup-file=no --project=$e census.jl $CSVFILE > logs/$L-base-census-$e.log 2>&1
done
echo "baseline census done $(date -Is)" >> logs/$L-controls.log
for r in 1 2; do
  JFLAGS="$BASE" bash runs.sh $L-base-$r 1; bash runs.sh $L-head-$r 1
done
echo "runs done $(date -Is)" >> logs/$L-controls.log
echo "# plain $(date -Is)" > $P
for r in w 1 2 3; do
  for jf in "$BASE" ""; do
    echo "== ${jf:+base}${jf:-head} run $r | load $(cut -d' ' -f1 /proc/loadavg)" >> $P
    nice -n 10 $JS $jf --startup-file=no --project=env_up $TW_ROOT/experiments/implementation/w134/plain.jl $CSVFILE none 2>&1 | grep -v "^ *$" | cut -c1-300 | head -20 >> $P
  done
done
echo "plain done $(date -Is)" >> logs/$L-controls.log
SPLIT_FIRST="$LOADS" nice -n 10 $JS --startup-file=no --project=env_forks $TW_ROOT/experiments/implementation/w152/p6/split.jl CSV DataFrames > logs/$L-split-forks.log 2>&1
echo "split done $(date -Is)" >> logs/$L-controls.log
JFLAGS="$BASE" bash suites.sh $L-base precompile > /dev/null 2>&1
bash suites.sh $L-head precompile > /dev/null 2>&1
echo "controls $L done $(date -Is)" >> logs/$L-controls.log
