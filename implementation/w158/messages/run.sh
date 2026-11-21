#!/bin/bash
# Collect the library's messages and scan them (README.md). One Julia process at a time, niced.
#     bash run.sh <label> [<library tree>]          after `source env.sh`; JN, the Julia binary (default julia-next)
# Writes ../logs/b-messages-<label>.tsv (the records), ../logs/b-messages-<label>-<run>.out (each run's output) and
# ../logs/b-messages-<label>-scan.txt (the findings and the counts).
set -u
H=$(cd "$(dirname "$0")" && pwd); R=${TW_ROOT:?source env.sh first}
LIB=$(cd "${2:-$R/TraitWorld}" && pwd); J=${JN:-$R/julia-next/julia}
P=$H/../logs/b-messages-$1
rm -f "$P".tsv "$P"-*.out
export MSG_OUT=$P.tsv MSG_SOURCES="$LIB/test:$R/experiments/docs-examples:$H" CAP=$H/capture.jl JULIA_PKG_OFFLINE=true
head="# $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia $(git -C "$(dirname "$(readlink -f "$J")")/../.." log -1 --format=%h 2>/dev/null) | library $LIB $(git -C "$LIB" log -1 --format=%h)$(git -C "$LIB" diff --quiet HEAD -- src test 2>/dev/null || echo +dirty)"
cd "$LIB"
run() {   # name, julia code
  { echo "$head"; nice -n 10 "$J" --startup-file=no --project=. -e "include(ENV[\"CAP\"]); using TraitWorld; println(\"pathof \", pathof(TraitWorld)); $2"; echo "exit $?"; } > "$P-$1.out" 2>&1
  echo "$1: $(tail -1 "$P-$1.out"), $(grep -c '' "$MSG_OUT" 2>/dev/null) records so far"
}
run library 'include("test/runtests.jl")'
for s in intro tutorial strict; do run "$s" "include(\"$R/experiments/docs-examples/$s.jl\")"; done
run cases "include(\"$H/cases.jl\")"
{ echo "$head"; python3 -I "$H/scan.py" "$P.tsv" "$P"-*.out; } > "$P-scan.txt"
tail -1 "$P-scan.txt"
