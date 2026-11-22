#!/bin/bash
# W-168, G-7 (E-523's open part): upstream's test suites of the forks (CSV, DataFrames) on the head, one suite per call,
# niced, one thread, the head's depot (forks/scripts/testsuites.sh's command, with the round's Julia and depot).
# The forks' tree must be clean before and after (Pkg.test must not change it).
#     bash g7_forks.sh <label> CSV|DataFrames|Tables      -> logs/g7-forks-<pkg>-<label>.log (the suite's output),
#                                                            logs/g7-forks-<label>.log (the summary lines)
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; p=$2
header "$LOGS/g7-forks-$label.log" "G-7 E-523 upstream's $p suite against the forks (forks/env_forks, Pkg.test)" H
check H
f=$LOGS/g7-forks-$p-$label.log; t0=$(date +%s)
(cd "$(tree H FORKS)" && JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_TW_VIEWCACHE=0 ALLOW_PRECOMPILE=1 TO=5400 \
   jl H --project=env_forks -e "using Pkg; Pkg.test(\"$p\")") > "$f" 2>&1; rc=$?
echo "$p | exit $rc | $(( $(date +%s) - t0 )) s | load before $(grep -m1 -o 'load-before [0-9. ]*' "$LOG") after $(load)" >> "$LOG"
grep -E 'Test Summary|tests passed|did not pass|Test Failed|Error During|Testing .* tests passed' "$f" | head -30 | cut -c1-200 >> "$LOG"
tail -5 "$f" | cut -c1-200 >> "$LOG"
echo "# forks tree: $(rev "$(tree H FORKS)")" >> "$LOG"
footer
