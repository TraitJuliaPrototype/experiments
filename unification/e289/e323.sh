#!/bin/bash
# E-323: DataFrames' `show` passes the stream on erased (`IOContext{IO}`; the forks' branch e323, 5c43492), on
# E-324's build; E-324 is the control (labels -w324, the forks at 4824b4b; its display timed in e323/show_time-before-w324.log):
#   1. the forks' environment precompiled (the home depot, as the forks use);
#   2. the display at an IOBuffer (e323/show_time.jl): its first call and 20 more, people.csv and a 10^4-row frame;
#   3. the forks' session, 3 runs (label forks-unified-$1), and one traced (`--trace-compile=stderr` with timing):
#      the `show` steps' compiles.
# Checks: the forks' digests and the REPL transcript (scripts/check_session.sh), DataFrames' suite (about 37 min).
set -u
: "${PYENV:?set PYENV to the Python of E-284}"
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); E=$R/experiments/unification
source "$R/env.sh"
L=${1:-w323}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
echo "forks-unified at $(git -C "$R/forks-unified" rev-parse --short HEAD) ($(git -C "$R/forks-unified" rev-parse --abbrev-ref HEAD)); unified $(git -C "$R/julia-unified" rev-parse --short HEAD)"

step "1. precompile"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -2)

step "2. the display at an IOBuffer"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && DATA=data nice -n 10 "$U" --startup-file=no --project=env_forks "$E/e323/show_time.jl" 2>&1 | tee "$E/e323/show_time-after-$L.log")

step "3. sessions"
bash "$H/run.sh" "forks-unified-$L" 3 > /dev/null 2>&1
grep -E '^fk-patched [123]' "$H/logs/forks-unified-$L.log" | grep -o -E 'show [0-9.]+|2_read_show [0-9.]+|3_read_show [0-9.]+|wall [0-9.]+' | tr '\n' ' '; echo
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JFLAGS="--trace-compile=stderr --trace-compile-timing" PATCHED=$U bash scripts/measure_session.sh 1 fk-patched > "$E/e323/session-traced-$L.txt" 2>&1; cp "${TMPDIR:-/tmp}/forks_session/fk-patched.out" "$E/e323/session-traced-$L.out")
cat "$E/e323/session-traced-$L.txt"

step "4. checks"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks -e 'using Pkg; Pkg.test("DataFrames")' > "$E/e323/dataframes-tests-$L.log" 2>&1; echo "DataFrames' tests exit $?")
grep -E "Testing DataFrames tests passed|Test Summary|Fail|Error" "$E/e323/dataframes-tests-$L.log" | head -8
step "done"
