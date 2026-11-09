#!/bin/bash
# E-339: the display erasing built as adopted (the user, 2026-11-09: "That said, b-display is adopted."):
# `unified` 8c4b93f867 (REPL's show_limited and Base's TextDisplay pass IOContext{IO}) with forks ddc20f6
# (DataFrames' display plain, its workload displaying once at IOContext{IO}(IOBuffer())). Checks: a TextDisplay
# probe, REPL's and Base's `show` suites, the forks' digests and REPL transcript; measured, not gated: the forks'
# session, a warm-up and 3 runs, the early build's forks-early before and after as the load's control.
# PYENV is required by run.sh only for Python's part, not run here. Logs: logs/e339-w339.log here.
set -u
: "${PYENV:?set PYENV (run.sh requires it)}"
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); E=$R/experiments/unification
source "$R/env.sh"
U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
echo "unified $(git -C "$R/julia-unified" rev-parse --short HEAD) (binary $("$U" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')), TraitWorld $(git -C "$R/TraitWorld-unified" rev-parse --short HEAD), forks $(git -C "$R/forks-unified" rev-parse --short HEAD)"
sess() {   # label
    bash "$H/run.sh" "$1" 3 > /dev/null 2>&1
    grep -E '^(fk-patched [123]|[123] )' "$H/logs/$1.log" | grep -o -E 'read [0-9.]+|show [0-9.]+|3_read_show [0-9.]+|write [0-9.]+|wall [0-9.]+' | tr '\n' ' '; echo " $1"
}
step "a TextDisplay probe"
nice -n 10 "$U" --startup-file=no -e '
    io = IOBuffer(); d = TextDisplay(io); display(d, [1 2; 3 4]); s = String(take!(io))
    println("TextDisplay of a matrix: ", repr(s))
    @assert s == "2×2 Matrix{Int64}:\n 1  2\n 3  4\n"
    io = IOBuffer(); display(TextDisplay(IOContext(io, :compact => true)), 1.0f0); println("compact passes through: ", repr(String(take!(io))))
    seen = Ref{Any}(nothing); struct P end; Base.show(io::IO, ::MIME"text/plain", ::P) = (seen[] = typeof(io); print(io, "P"))
    display(TextDisplay(IOBuffer()), P()); println("show sees ", seen[]); @assert seen[] === IOContext{IO}'
step "the forks precompiled"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && nice -n 10 "$U" --startup-file=no --project=env_forks -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -1)
step "control before"; sess forks-early-w339a
step "the forks' session"; sess forks-unified-w339
step "the forks' checks"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
step "control after"; sess forks-early-w339b
step "REPL's and show's tests"
(cd "$R/julia-unified" && nice -n 10 ./julia --startup-file=no -e 'Base.runtests(["REPL", "show"]; ncores=1)' > "$H/logs/e339-tests.log" 2>&1; echo "tests exit $?")
grep -E "Overall|SUCCESS|FAILURE|^ *(REPL|show) " "$H/logs/e339-tests.log" | tail -6
step "done"
