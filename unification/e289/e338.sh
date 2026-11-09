#!/bin/bash
# E-338: arm B-display (the plan of 2026-11-09 on IO, §7 question 3): the REPL's display erases the stream, on
# `unified`'s branch `b-display` (REPL's `show_limited` passes `IOContext{IO}`). The forks' session, a warm-up and
# 3 runs each, the early build's `forks-early` before and after as the load's control, in three arms:
#   (0) forks 4824b4b: DataFrames' code and workload as before E-337;
#   (w) forks b-display d196bed: DataFrames' code unchanged, its workload displaying once at IOContext{IO}(IOBuffer());
#   (e) forks unified a8fe1b5: E-337's erasing entries.
# Each arm: the forks' environment precompiled (the home depot, as the forks use), the sessions, and for (0) and (w)
# the forks' digests and the REPL transcript. Then one traced session of (w), REPL's test suite, and the forks back
# on `unified`. PYENV is required by run.sh only for Python's part, not run here.
# Logs: logs/e338-w338.log here, the sessions' in logs/forks-*-w338*.log, the trace in ../e323/session-traced-w338w.*
set -u
: "${PYENV:?set PYENV (run.sh requires it)}"
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); E=$R/experiments/unification
source "$R/env.sh"
U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
echo "unified $(git -C "$R/julia-unified" rev-parse --short HEAD) ($(git -C "$R/julia-unified" rev-parse --abbrev-ref HEAD)), TraitWorld $(git -C "$R/TraitWorld-unified" rev-parse --short HEAD)"
sess() {   # label
    bash "$H/run.sh" "$1" 3 > /dev/null 2>&1
    grep -E '^(fk-patched [123]|[123] )' "$H/logs/$1.log" | grep -o -E 'read [0-9.]+|show [0-9.]+|3_read_show [0-9.]+|write [0-9.]+|wall [0-9.]+' | tr '\n' ' '; echo " $1"
}
arm() {    # name commit
    step "arm $1: forks at $2"
    git -C "$R/forks-unified" checkout -q "$2" || exit 1
    (cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1)
    sess "forks-unified-w338$1"
    if [ "$1" != e ]; then
        (cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
    fi
}
step "control before"; sess forks-early-w338a
arm 0 4824b4b
arm w b-display
arm e unified
step "control after"; sess forks-early-w338b
step "the traced session of (w)"
git -C "$R/forks-unified" checkout -q b-display
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JFLAGS="--trace-compile=stderr --trace-compile-timing" PATCHED=$U bash scripts/measure_session.sh 1 fk-patched > "$E/e323/session-traced-w338w.txt" 2>&1; cp "${TMPDIR:-/tmp}/forks_session/fk-patched.out" "$E/e323/session-traced-w338w.out")
git -C "$R/forks-unified" checkout -q unified
step "REPL's tests"
(cd "$R/julia-unified" && nice -n 10 ./julia --startup-file=no -e 'Base.runtests(["REPL"]; ncores=1)' > "$H/logs/e338-repl-tests.log" 2>&1; echo "REPL tests exit $?")
grep -E "Overall|SUCCESS|FAILURE" "$H/logs/e338-repl-tests.log" | tail -3
step "done"
