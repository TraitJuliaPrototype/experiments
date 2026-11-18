#!/bin/bash
# W-163: run one of the teaching pages' scripts N times, one process at a time, and count the faults.
#     bash repro.sh <julia binary> <label> <N> [script, default tutorial.jl] [extra julia/env set via ENV]
# Each run's output: logs/<label>-<i>.log; the count: logs/<label>-summary.log.
# Core files are off (ulimit -c 0) unless CORE=1; a core lands in TraitWorld/ and is about 0.5 GB: read, then delete it.
# Extra environment for julia (for example JULIA_GC_ALLOC_POOL=...) passes through.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
JB=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); L=$2; N=$3; S=${4:-tutorial.jl}
source "$H/env.sh" >/dev/null 2>&1   # the workspace's env.sh (it sets J, the baseline: the binary here is JB) and this directory's depot
[ "${CORE:-0}" = 1 ] || ulimit -c 0
SUM=$H/logs/$L-summary.log
echo "# $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $("$JB" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)') | TraitWorld $(git -C "$R/TraitWorld" log -1 --format=%h) | $S x $N" | tee -a "$SUM"
nfault=0; nfail=0
for i in $(seq 1 "$N"); do
  f=$H/logs/$L-$i.log; s=$(date +%s)
  (cd "$R/TraitWorld" && JULIA_PKG_OFFLINE=true nice -n 19 "$JB" --project=. --startup-file=no "$R/experiments/docs-examples/$S") > "$f" 2>&1; rc=$?
  if grep -q 'signal (11)\|signal 11\|Segmentation fault\|signal (6)\|Aborted' "$f"; then nfault=$((nfault+1)); k=FAULT
  elif [ $rc != 0 ]; then nfail=$((nfail+1)); k=FAIL; else k=ok; rm -f "$f"; fi
  echo "run $i | exit $rc | $k | $(( $(date +%s) - s )) s" | tee -a "$SUM"
done
echo "TOTAL $L: $nfault faults, $nfail other failures, of $N runs" | tee -a "$SUM"
