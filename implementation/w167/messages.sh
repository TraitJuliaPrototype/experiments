#!/bin/bash
# W-167: the messages' tool (../w158/messages/: capture.jl, cases.jl, scan.py, unchanged) on a library tree, its logs
# here. The library's tests, the documentation's examples (intro, tutorial, strict) and cases.jl, each with capture.jl.
#     bash messages.sh <label> [<library tree>=wt/w158g-tw]    -> logs/messages-<label>-*.out, -scan.txt
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); M=$H/../w158/messages
LIB=$(cd "$R/${2:-wt/w158g-tw}" && pwd)
P=$H/logs/messages-$1
rm -f "$P".tsv "$P"-*.out
export MSG_OUT=$P.tsv MSG_SOURCES="$LIB/test:$R/experiments/docs-examples:$M" CAP=$M/capture.jl
head="# $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia $(git -C "$R/julia-next" log -1 --format=%h) | library $LIB $(git -C "$LIB" log -1 --format=%h)$(git -C "$LIB" diff --quiet HEAD -- src test 2>/dev/null || echo +dirty)"
cd "$LIB"
run() {   # name, julia code
  { echo "$head"; "$H/jl.sh" --project=. -e "include(ENV[\"CAP\"]); using TraitWorld; println(\"pathof \", pathof(TraitWorld)); $2"; echo "exit $?"; } > "$P-$1.out" 2>&1
  echo "$1: $(tail -1 "$P-$1.out"), $(grep -c '' "$MSG_OUT" 2>/dev/null) records so far"
}
run library 'include("test/runtests.jl")'
for s in intro tutorial strict; do run "$s" "include(\"$R/experiments/docs-examples/$s.jl\")"; done
run cases "include(\"$M/cases.jl\")"
{ echo "$head"; python3 -I "$M/scan.py" "$P.tsv" "$P"-*.out; } > "$P-scan.txt"
tail -1 "$P-scan.txt"
