#!/bin/bash
# W-143d (E-540): Base's tests on a tree, one worker:  TREE=<tree> bash tests.sh <label> <test>...  -> logs/tests-<label>.log
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"
label=$1; shift
log=$H/logs/tests-$label.log
echo "# W-143d tests $label on $TREE $(git -C $TW_ROOT/$TREE rev-parse --short=10 HEAD) | $(date -Is) | load-before $(cut -d' ' -f1-3 /proc/loadavg)" > $log
list=$(printf '"%s",' "$@")
s=$(date +%s)
nice -n 10 $JN --startup-file=no -e "Base.runtests([$list]; ncores=1)" >> $log 2>&1
echo "# done rc $? | $(( $(date +%s) - s )) s | load-after $(cut -d' ' -f1-3 /proc/loadavg)" >> $log
tail -25 $log
