#!/bin/bash
# W-143e: the gates on the branch, by pattern, one run each, one after another -> logs/gates-<label>.log
H=$(cd "$(dirname "$0")" && pwd); cd "$H"; L=$1; shift
export TREE=${TREE:-wt/w143-julia}; source env.sh > /dev/null 2>&1
G=$TW_ROOT/experiments/implementation/gates
{ echo "# W-143e gates $L on $TREE $(git -C $TW_ROOT/$TREE rev-parse --short=10 HEAD) | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg)"
  for p in "$@"; do echo "## pattern ${p:-(all, with the stage gates)}"; bash $G/run_all.sh $TW_ROOT/$TREE "$p" 2>&1; done
  echo "# done $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg)"; } > logs/gates-$L.log
echo GATESDONE
