#!/bin/bash
# W-159: the short round, the rows one after another, one Julia job at a time, niced (each row's driver: rows/).
#     bash run_round.sh <label> [row ...]            default: every row of ROWS below, in that order
# Before it (once, by the main session): the freeze (W-158 merged, julia-next rebuilt with BUILD EXIT 0, the freeze
# tag), then
#     bash trees.sh                                   the tag's worktrees under wt/w159-tag/ (TraitTables, TraitCSV,
#                                                     TraitReport, forks)
#     bash prepare.sh H; bash prepare.sh B; bash prepare.sh V      every image each setting needs (see the costs)
# The tag's binary names 8fccf1e182* though its tree is at 7b374f39ce (built before its last commit, one file of the
# compiler's bootstrap): every row that runs B needs ALLOW_BINARY_MISMATCH=B, or julia-unified rebuilt (README).
# Between rows the script waits while the machine's 1-minute load is at or above half its cores.
# Minutes per row (from the earlier logs; the load 1 to 7 of 128): rows marked * are over about ten minutes; the
# README names the smaller vehicle.
#   g7_annotations   <1   git reads only
#   g2_calls          3   2 processes x H, B at 10^7 calls (a smoke at 10^6: 4 s a process)
#   g4_plain          4   7 cells x (a warm-up + 3) (E-499: 20 cells in 2 minutes)
#   g1_loads          7   3 environments x 2 orders x (a warm-up + 2) x H, B (E-376: 18 cells in 3.5 minutes)
#   g1_edit           5   3 kinds x (a warm-up + 2) x H, B
#   g6_sessions       2   2 sessions x 4 x H, B
#   oi228             1   2 processes x H, B (a smoke on B: 5 s)
#   g5_messages       6   15 trait cases + 3 strict x H, B; 14 plain x V, H; SciML 2 x H, B
#   g4_loads          6   10 rows x 4 x H, B (walk only)
#   g2_nd             5   (a warm-up + 2) x H, B at 43-45 s a session; 8 with UPSTREAM=1
#   g4_images         8   8 images x H, B, written anew
#   g6_small          8*  13 programs: session, build, run (H)
#   g6_builds        12*  6 builds with their images step (H)
#   g7_suites        25*  the demonstrators' suites and sessions, NetworkDynamics' subset (H)
# Not in ROWS: rows/oi225.sh, a bisection of Julia builds (sustained use, WIDE=0): 3 to 9 builds of about 14 minutes,
# each with its images (about 3 minutes) and its measure (about 3 minutes).
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd)
label=$1; shift
ROWS=${*:-g7_annotations g2_calls g4_plain g1_loads g1_edit g6_sessions oi228 g5_messages g4_loads g2_nd g4_images g6_small g6_builds g7_suites}
NCPU=$(getconf _NPROCESSORS_ONLN); HALF=$((NCPU / 2))
S=$H/logs/round-$label.log
echo "# W-159 round $label $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg) | rows: $ROWS" | tee -a "$S"
for row in $ROWS; do
  while awk -v h=$HALF '{exit !($1 >= h)}' /proc/loadavg; do echo "# $(date +%T) load $(cut -d' ' -f1 /proc/loadavg) >= $HALF: waiting" | tee -a "$S"; sleep 60; done
  t0=$(date +%s)
  bash "$H/rows/$row.sh" "$label"; rc=$?
  echo "$row | exit $rc | $(( ($(date +%s) - t0 + 30) / 60 )) min | load $(cut -d' ' -f1-3 /proc/loadavg)" | tee -a "$S"
done
echo "# done $(date -Is)" | tee -a "$S"
