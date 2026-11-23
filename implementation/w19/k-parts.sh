#!/bin/bash
# W-19 seventh part: build a part of the series alone in wt/w19-julia and run its tests and the gates.
#     bash k-parts.sh <n> <label> <commit> "<Base tests>" [tw]     -> logs/k-build<n>-<label>.tw-build.log,
#                                                                     logs/k-part-<label>.log
cd /p/projects/coen/julia-trait-bound
source env.sh >/dev/null 2>&1
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w19:$TW_ROOT/.julia-depot: JULIA_PKG_OFFLINE=true
ulimit -c 0
n=$1; label=$2; c=$3; tests=$4; extra=" ${5:-} "
[ -f /tmp/claude-harvest/k-skip-$label ] && exit 0   # a part dropped from the queue (the build budget)
L=experiments/implementation/w19/logs; T=wt/w19-julia; LOG=$L/k-part-$label.log
# wait while the machine is at half load or more
while [ $(cut -d. -f1 /proc/loadavg) -ge 64 ]; do sleep 60; done
rm -f $T/tw-build.log; git -C $T checkout -q --detach $c || { echo "checkout of $c failed" >> $LOG; exit 1; }
echo "# build $n $label $(git -C $T rev-parse --short=10 HEAD) start $(date +%T) load $(cut -d' ' -f1-3 /proc/loadavg)" > $LOG
WIDE=0 nice tools-local/build.sh $T > /dev/null 2>&1
cp $T/tw-build.log $L/k-build$n-$label.tw-build.log
echo "# $(tail -1 $T/tw-build.log) $(grep 'done: wall' $T/tw-build.log | sed 's/.*done: //') sys.so $(stat -c %s $T/usr/lib/julia/sys.so 2>/dev/null)" >> $LOG
grep -q "BUILD EXIT 0" $T/tw-build.log || exit 1
{ echo "## Base tests: $tests"; nice $T/julia --startup-file=no -e "Base.runtests(split(\"$tests\"); ncores=1)" 2>&1 | grep -E "Overall|^\s+\S+ +\|| SUCCESS|FAILURE|Error During|Test Failed|at .*/test/.*jl:[0-9]+$" | head -40; } >> $LOG
{ echo "## gates"; bash experiments/implementation/gates/run_all.sh $T 2>&1 | grep -E "^FAIL|gates:|stage gates:"; } >> $LOG
if echo "$extra" | grep -q " tw "; then
  { echo "## TraitWorld's suite"; (cd TraitWorld && nice ../$T/julia --startup-file=no --project=. test/runtests.jl 2>&1 | grep -E "Error|Fail|ERROR|Test Summary" | head -8; echo "exit ${PIPESTATUS[0]}"); } >> $LOG
fi
echo "# done $(date +%T) load $(cut -d' ' -f1-3 /proc/loadavg)" >> $LOG
