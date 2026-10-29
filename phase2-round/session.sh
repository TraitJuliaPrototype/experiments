#!/bin/bash
# E-233/E-234: the forks' REPL session (forks/scripts/session.jl, as forks/scripts/measure_session.sh runs it:
# a real REPL on a pseudo-terminal) in one of four modes:
#     bash session.sh <mode> <tag> [runs=2] [env=env_forks]
#   time     the session with Julia's compile counter at each mark (enabled with -e before the REPL starts)
#   detail   as time, plus @time_imports on the imports, TraitWorld's load report of the session's first uses,
#            and the CodeInstances created after the imports by owner and module (rec.jl); the probes run
#            between marks ("probe", "end"), outside the steps; with --trace-compile-timing (logs/<tag>/trace-<i>.jl)
#   record   E-234: every CodeInstance created after the imports recorded (rec.jl), split at `using InlineStrings`
# TRACE=1 adds --trace-compile-timing in any mode. NOE=1 runs without -e (no compile counter: as forks/scripts/measure_session.sh). HINTS=0 turns the REPL's typing hints off (they infer and compile in the background as the input arrives).
#   cache    E-234: the emulated cache loaded with the imports (SessionCacheFk1, env_cache_fk; make_cache.sh)
# A warm-up run first (logs/<tag>/<mode>-w.out), then <runs>. Raw REPL output in logs/<tag>/; one summary line
# per run from parse.py. One Julia job at a time (flock), niced, under a kill timeout.
set -u
cd "$(dirname "$0")"; H=$PWD; R=$(cd .. && cd .. && pwd)
mode=$1; tag=$2; runs=${3:-2}; env=${4:-$R/forks/env_forks}
J=$R/julia-1.13/julia
mkdir -p logs/$tag
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 DATA=$R/forks/data LINES=40 COLUMNS=120
TW='Base.root_module(Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld"))'
gen() {
    awk -v mode="$mode" -v h="$H" -v tw="$TW" -v out="$H/logs/$tag" '
        /^_m\(s\) = / { print "_m(s) = println(\"T \", s, \" \", time(), \" \", Base.cumulative_compile_time_ns()[1] / 1e9, \" \", Base.gc_time_ns() / 1e9)"; next }
        /^using CSV/ {
            if (mode == "detail") print "@time_imports " $0
            else if (mode == "cache") print "using CSV, DataFrames, Statistics, Dates, SessionCacheFk1"
            else print
            next }
        /^_m\("imports"\)/ { print
            if (mode == "detail" || mode == "record") { print "include(\"" h "/rec.jl\"); _snap!()" }
            if (mode == "detail") { print "TW = " tw "; TW.loadreport_switch!(true)" }
            if (mode == "detail" || mode == "record") print "_m(\"probe\")"
            next }
        /^using InlineStrings/ {
            print   # E-234: the part recorded after this using is empty (CSV loads InlineStrings), so one cache

            if (mode == "record") print "_split!()"
            next }
        /^exit\(\)/ {
            if (mode == "detail") { print "_m(\"end\")"; print "TW.loadreport(; top = 8)"; print "_count()" }
            if (mode == "record") print "_record(\"" h "/cache/SessionCacheFk.jls\")"
            print; next }
        { print }' $R/forks/scripts/session.jl
}
for i in w $(seq 1 $runs); do
    f=logs/$tag/$mode-$i.out
    gen > logs/$tag/session-$mode.jl
    jf=""; [ "${TRACE:-0}" = 1 ] && jf="--trace-compile=$H/logs/$tag/trace-$i.jl --trace-compile-timing"
    [ $mode = detail ] && jf="--trace-compile=$H/logs/$tag/trace-$i.jl --trace-compile-timing"
    ex='Base.cumulative_compile_timing(true)'
    [ "${HINTS:-1}" = 0 ] && ex="$ex; atreplinit(r -> (r.options.hint_tab_completes = false))"   # the REPL's typing hints off
    # the clock starts inside the lock: a wait for another job's lock is not the session's start
    flock /tmp/claude-1000/julia-review.lock bash -c 'load=$(cut -d" " -f1-3 /proc/loadavg); s=$(date +%s.%N)
        nice -n 19 timeout -s KILL 600 script -qec "$1" /dev/null < "$2" > "$3" 2>&1
        printf "\nS %s E %s load %s\n" "$s" "$(date +%s.%N)" "$load" >> "$3"' _ \
        "$J --startup-file=no $jf $([ "${NOE:-0}" = 1 ] || echo "-e '$ex'") -i --banner=no --project=$env" logs/$tag/session-$mode.jl $f
    load=$(grep -ao "load [0-9. ]*$" $f | tail -1 | cut -d" " -f2-)
    echo "$mode $i load $load | $(python3 -I parse.py $f)"
done
