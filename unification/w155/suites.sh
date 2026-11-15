#!/bin/bash
# W-155: the suites after each commit on `next` (the plan, stage 3): Julia's `core` and `subtype` tests and
# the compiler's quick tests, the library's suite, the forks' session digests (E-308), the deep gate.
# One job at a time, niced. Logs: logs/<label>-<name>.log; a line per suite in logs/<label>-summary.log.
#     bash suites.sh <julia tree> <label> [names...]   names: tests library digests gate (default: all)
set -u
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"
T=$TW_ROOT/$1; L=$2; shift 2
J=$T/julia; LOG=$H/logs; S=$LOG/$L-summary.log
LIB=${LIB:-$TW_ROOT/TraitWorld-w155}
rev() { git -C "$1" log -1 --format=%h; }
note() { echo "$*" | tee -a "$S"; }
note "# $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $1 $(rev $T) | library $(basename $LIB) $(rev $LIB) | forks $(rev $TW_ROOT/forks-unified)"
run() {
  case $1 in
    tests)
      for t in core subtype Compiler/inline Compiler/inference; do
        f=$LOG/$L-test-$(echo $t | tr / _).log
        s=$(date +%s)
        nice -n 10 "$J" --startup-file=no -e "Base.runtests([\"$t\"]; ncores=1)" > "$f" 2>&1; rc=$?
        note "test $t | exit $rc | $(( $(date +%s) - s )) s | $(grep -E 'SUCCESS|FAILURE' "$f" | tail -1)"
      done ;;
    library)
      f=$LOG/$L-library.log; s=$(date +%s)
      (cd "$LIB" && nice -n 10 "$J" --startup-file=no --project=. test/runtests.jl) > "$f" 2>&1; rc=$?
      note "library | exit $rc | $(( $(date +%s) - s )) s | $(grep -E 'Test Summary|tests passed|Pass|Fail|Error' "$f" | tail -2 | tr '\n' ' ' | cut -c1-200)" ;;
    digests)
      f=$LOG/$L-digests.log; s=$(date +%s)
      D=$TW_ROOT/forks-unified/data
      (export DATA=$D JULIA_TW_VIEWCACHE=0 LINES=40 COLUMNS=120
       nice -n 10 "$J" --startup-file=no --project="$H/env_session" "$TW_ROOT/forks-unified/scripts/session_check.jl" > "$LOG/$L-digests-forks.txt" 2> "$f"
       nice -n 10 "$J" --startup-file=no --project="$TW_ROOT/forks-unified/env_upstream" "$TW_ROOT/forks-unified/scripts/session_check.jl" > "$LOG/$L-digests-upstream.txt" 2>> "$f")
      if [ -s "$LOG/$L-digests-forks.txt" ] && diff -q "$LOG/$L-digests-forks.txt" "$LOG/$L-digests-upstream.txt" > /dev/null; then
        note "digests | equal: $(wc -l < "$LOG/$L-digests-forks.txt") steps | $(( $(date +%s) - s )) s"
      else
        note "digests | DIFFER or missing | see $f"
      fi ;;
    gate)
      f=$LOG/$L-gate-deep.log
      nice -n 10 "$J" --startup-file=no "$H/gate_deep.jl" > "$f" 2>&1; rc=$?
      note "gate_deep | exit $rc | $(tail -1 "$f")" ;;
  esac
}
[ $# -eq 0 ] && set -- gate tests library digests
for n in "$@"; do run $n; done
