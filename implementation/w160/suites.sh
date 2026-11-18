#!/bin/bash
# W-160: the suites after a commit on `next`: Julia's `core`, `subtype`, `Compiler/inline` and
# `Compiler/inference` tests, and the library's suite. One job at a time, niced.
# Logs: logs/<label>-<name>.log; a line per suite in logs/<label>-summary.log.
#     bash suites.sh <julia tree> <label> [names...]   names: tests library (default: both)
set -u
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"
TREE=$1; T=$TW_ROOT/$1; L=$2; shift 2
J=$T/julia; LOG=$H/logs; S=$LOG/$L-summary.log
LIB=${LIB:-$TW_ROOT/TraitWorld}
rev() { git -C "$1" log -1 --format=%h; }
note() { echo "$*" | tee -a "$S"; }
note "# $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $TREE $(rev $T)$(git -C $T diff --quiet HEAD -- src Compiler base || echo +dirty) | library $(basename $LIB) $(rev $LIB)$(git -C $LIB diff --quiet || echo '+dirty')"
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
  esac
}
[ $# -eq 0 ] && set -- tests library
for n in "$@"; do run $n; done
