#!/bin/bash
# W-157: the suites after each build of `next-s3` (the plan, stage 5): Julia's `core`, `subtype`, `Compiler/inline`,
# `Compiler/inference` and the test files of the Base files stage 5 touches; the library's suite; the forks'
# session digests (E-308); the deep class's gate (W-155's `gate_deep.jl`); Base's `precompile` test (E-479).
# One job at a time, niced. Logs: logs/<label>-<name>.log; a line per suite in logs/<label>-summary.log.
# JFLAGS="-J <image>" runs another system image on the same runtime.
#     [JFLAGS=...] bash suites.sh <label> [names...]   names: tests basetests library digests gate precompile
set -u
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"
L=$1; shift
J="$JS ${JFLAGS:-}"; LOG=$H/logs; S=$LOG/$L-summary.log
LIB=$TW_ROOT/TraitWorld-s3
rev() { git -C "$1" log -1 --format=%h; }
note() { echo "$*" | tee -a "$S"; }
note "# $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-s3 $(rev $TW_ROOT/julia-s3) JFLAGS '${JFLAGS:-}' | library $(rev $LIB) | forks $(rev $TW_ROOT/forks-unified)"
runtests() {
  for t in "$@"; do
    f=$LOG/$L-test-$(echo $t | tr / _).log; s=$(date +%s)
    nice -n 10 $J --startup-file=no -e "Base.runtests([\"$t\"]; ncores=1)" > "$f" 2>&1; rc=$?
    note "test $t | exit $rc | $(( $(date +%s) - s )) s | $(grep -E 'SUCCESS|FAILURE' "$f" | tail -1)"
  done
}
run() {
  case $1 in
    tests) runtests core subtype Compiler/inline Compiler/inference ;;
    basetests) runtests errorshow int numbers strings/basic channels ambiguous ;;
    precompile) runtests precompile ;;
    library)
      f=$LOG/$L-library.log; s=$(date +%s)
      (cd "$LIB" && nice -n 10 $J --startup-file=no --project=. test/runtests.jl) > "$f" 2>&1; rc=$?
      note "library | exit $rc | $(( $(date +%s) - s )) s | $(grep -E 'Test Summary|tests passed|Pass|Fail|Error' "$f" | tail -2 | tr '\n' ' ' | cut -c1-200)" ;;
    digests)
      f=$LOG/$L-digests.log; s=$(date +%s)
      D=$TW_ROOT/forks-unified/data
      (export DATA=$D JULIA_TW_VIEWCACHE=0 LINES=40 COLUMNS=120
       nice -n 10 $J --startup-file=no --project="$H/env_session" "$TW_ROOT/forks-unified/scripts/session_check.jl" > "$LOG/$L-digests-forks.txt" 2> "$f"
       nice -n 10 $J --startup-file=no --project="$TW_ROOT/forks-unified/env_upstream" "$TW_ROOT/forks-unified/scripts/session_check.jl" > "$LOG/$L-digests-upstream.txt" 2>> "$f")
      if [ -s "$LOG/$L-digests-forks.txt" ] && diff -q "$LOG/$L-digests-forks.txt" "$LOG/$L-digests-upstream.txt" > /dev/null; then
        note "digests | equal: $(wc -l < "$LOG/$L-digests-forks.txt") steps | $(( $(date +%s) - s )) s"
      else
        note "digests | DIFFER or missing | see $f"
      fi ;;
    gate)
      f=$LOG/$L-gate-deep.log
      nice -n 10 $J --startup-file=no "$TW_ROOT/experiments/unification/w155/gate_deep.jl" > "$f" 2>&1; rc=$?
      note "gate_deep | exit $rc | $(tail -1 "$f")" ;;
  esac
}
[ $# -eq 0 ] && set -- gate tests basetests library digests
for n in "$@"; do run $n; done
