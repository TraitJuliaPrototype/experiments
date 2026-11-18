#!/bin/bash
# W-156, second part: the regression control and the audit's census for the forks' session. On julia-next, with
# `env_session/` (the forks, the library), fresh processes with one thread, niced: a warm-up (it writes the images
# where they are stale) and N runs of `forks_session.jl`. Each run: its wall time, the session's time and of it
# compiling, the number of compiles (`--trace-compile`), and its digests against upstream's (the same digests
# `../w161/suites.sh <label> digests` compares: upstream's from `forks/env_upstream`, made once here). The last
# run is followed by one, not timed, that lists the instances with code in the forks' packages (logs/b-<tag>-instances.tsv), for
# `compare_instances.py`.
#     [TREE=<julia tree>] bash forks_session.sh <tag> [N]       -> logs/b-forks-<tag>.log, logs/b-forks-<tag>.trace (the last run's compiles)
set -u
H=$(cd "$(dirname "$0")" && pwd)
# TREE=<julia tree> (relative to the workspace root) runs with that tree's binary and the third part's depot
# (env-c.sh); the default is julia-next with the second part's (env.sh)
if [ -n "${TREE:-}" ]; then source "$H/env-c.sh"; JN=$TW_ROOT/$TREE/julia; else source "$H/env.sh"; TREE=julia-next; fi
tag=$1; N=${2:-3}
LOG=$H/logs/b-forks-$tag.log; T=$(mktemp -d)
rev() { git -C "$TW_ROOT/$1" log -1 --format=%h; }
dirty() { git -C "$TW_ROOT/$1" diff --quiet HEAD -- . 2>/dev/null || echo +dirty; }
export DATA=$TW_ROOT/forks/data JULIA_TW_VIEWCACHE=0 LINES=40 COLUMNS=120
echo "# W-156 forks' session $tag $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $TREE $(rev $TREE) TraitWorld $(rev TraitWorld)$(dirty TraitWorld) forks $(rev forks)$(dirty forks)" | tee "$LOG"
up=$H/logs/b-digests-upstream.txt
if [ ! -s "$up" ]; then
  nice -n 10 "$JN" -t 1 --startup-file=no --project="$TW_ROOT/forks/env_upstream" "$TW_ROOT/forks/scripts/session_check.jl" > "$up" 2> "$T/up.err"
fi
for r in $(seq 0 $N); do
  s=$(date +%s.%N)
  line=$(DIGESTS=$T/d.txt nice -n 10 "$JN" -t 1 --startup-file=no --project="$H/env_session" \
           --trace-compile="$T/trace" "$H/forks_session.jl" 2> "$T/err" | grep '^session')
  e=$(date +%s.%N)
  d=equal; diff -q "$T/d.txt" "$up" > /dev/null || d=DIFFER
  [ $r = 0 ] && { echo "warm-up: digests $d ($(wc -l < "$T/d.txt") steps)" | tee -a "$LOG"; continue; }
  echo "run $r: wall $(echo "$e - $s" | bc | cut -c1-6) s | $line | compiles $(grep -c '^precompile' "$T/trace") | digests $d ($(wc -l < "$T/d.txt") steps)" | tee -a "$LOG"
done
# one more run, not timed: the instances with code in the forks' packages after the session
DIGESTS=$T/d2.txt INSTANCES=$H/logs/b-$tag-instances.tsv nice -n 10 "$JN" -t 1 --startup-file=no --project="$H/env_session" \
  "$H/forks_session.jl" 2>> "$T/err" | grep '^instances' | tee -a "$LOG"
echo "# load after $(cut -d' ' -f1-3 /proc/loadavg)" | tee -a "$LOG"
cp "$T/d.txt" "$H/logs/b-digests-forks-$tag.txt"
cp "$T/trace" "$H/logs/b-forks-$tag.trace"         # what the last timed run compiled
rm -rf "$T"
