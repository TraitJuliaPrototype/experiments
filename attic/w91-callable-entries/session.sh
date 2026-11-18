#!/bin/bash
# E-241: the forks' REPL session (forks/scripts/session.jl in a real REPL on a pseudo-terminal), E-233's harness
# (experiments/phase2-round/session.sh) with the REPL's typing hints off, in a private depot:
#     bash session.sh <mode> <tag> <env> [runs=2]
#   time    Julia's compile counter at each mark
#   wl      as time, with W91Workload (a stand-in for a forks' workload over the session's ByRow steps) loaded with the imports
#   count   as wl, plus the census (census.jl) after the session: the CodeInstances made after the imports
#           without a hash, and those of `enter_callable`, `_callable_result` (any hash), by signature
# A warm-up run first (logs/<tag>/<mode>-w.out), then <runs>. One summary line per run (../phase2-round/parse.py).
set -u
cd "$(dirname "$0")"; H=$PWD; R=$(cd ../.. && pwd)
mode=$1; tag=$2; env=$3; runs=${4:-2}
J=$R/julia-1.13/julia
mkdir -p logs/$tag
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 DATA=$R/forks/data LINES=40 COLUMNS=120
export JULIA_DEPOT_PATH=${W91_DEPOT:?set W91_DEPOT to the private depot}:$HOME/.julia:
gen() {
    awk -v mode="$mode" -v h="$H" '
        /^_m\(s\) = / { print "_m(s) = println(\"T \", s, \" \", time(), \" \", Base.cumulative_compile_time_ns()[1] / 1e9, \" \", Base.gc_time_ns() / 1e9)"; next }
        /^using CSV/ { if (mode == "wl" || mode == "count") print "using CSV, DataFrames, Statistics, Dates, W91Workload"; else print; next }
        /^_m\("imports"\)/ { print; if (mode == "count") { print "include(\"" h "/census.jl\"); census_snap()"; print "_m(\"probe\")" }; next }
        /^exit\(\)/ { if (mode == "count") { print "_m(\"end\")"; print "census(); census_entries()" }; print; next }
        { print }' $R/forks/scripts/session.jl
}
for i in w $(seq 1 $runs); do
    f=logs/$tag/$mode-$i.out
    gen > logs/$tag/session-$mode.jl
    ex='Base.cumulative_compile_timing(true); atreplinit(r -> (r.options.hint_tab_completes = false))'
    flock /tmp/claude-1000/julia-review.lock bash -c 'load=$(cut -d" " -f1-3 /proc/loadavg); s=$(date +%s.%N)
        nice -n 19 timeout -s KILL 600 script -qec "$1" /dev/null < "$2" > "$3" 2>&1
        printf "\nS %s E %s load %s\n" "$s" "$(date +%s.%N)" "$load" >> "$3"' _ \
        "$J --startup-file=no -e '$ex' -i --banner=no --project=$env" logs/$tag/session-$mode.jl $f
    load=$(grep -ao "load [0-9. ]*$" $f | tail -1 | cut -d" " -f2-)
    echo "$mode $i load $load | $(python3 -I ../phase2-round/parse.py $f)"
done
