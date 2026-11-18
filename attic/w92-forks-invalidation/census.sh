#!/bin/bash
# E-238 (W-92): the forks' REPL session (forks/scripts/session.jl, a real REPL on a pseudo-terminal, as
# experiments/phase2-round/session.sh runs it) with Julia's invalidation log on from before the REPL starts,
# the compile trace with timing, and census.jl's report at the end.
#     bash census.sh <tag> [env=forks/env_forks] [runs=1]
# The REPL's typing hints are off. A warm-up first (logs/<tag>/census-w.*), then <runs>.
# Output: logs/<tag>/census-<i>.out (the REPL), census-<i>.txt (census.jl: the method-insertion log),
# roots-<i>.txt (census.jl: the trace's roots after the load mark, classified; the image code rejected at load), trace-<i>.jl.
set -u
cd "$(dirname "$0")"; H=$PWD; R=$(cd ../.. && pwd)
tag=$1; env=${2:-$R/forks/env_forks}; runs=${3:-1}
J=${JULIA:-$R/julia-1.13/julia}
mkdir -p logs/$tag
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 DATA=$R/forks/data LINES=40 COLUMNS=120
for i in w $(seq 1 $runs); do
    awk -v h="$H" -v out="$H/logs/$tag/census-$i.txt" -v tr="$H/logs/$tag/trace-$i.jl" -v roots="$H/logs/$tag/roots-$i.txt" '
        /^_m\(s\) = / { print "_m(s) = println(\"T \", s, \" \", time(), \" \", Base.cumulative_compile_time_ns()[1] / 1e9, \" \", Base.gc_time_ns() / 1e9)"; next }
        /^_m\("start"\)/ { print; print "global _NS = length(_INVLOG)"; next }
        /^_m\("imports"\)/ { print; print "include(\"" h "/census.jl\"); _loadmark!(); _OFF0 = filesize(\"" tr "\")"; print "_m(\"probe\")"; next }
        /^exit\(\)/ { print "_m(\"end\")"; print "_OFF1 = filesize(\"" tr "\")"; print "_census(\"" out "\")"; print "_roots(\"" tr "\", \"" roots "\", _OFF0, _OFF1)"; print; next }
        { print }' $R/forks/scripts/session.jl > logs/$tag/session-census.jl
    ex='Base.cumulative_compile_timing(true); global _INVLOG = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1); Base.Compiler.ReinferUtils.debug_method_invalidation(true); atreplinit(r -> (r.options.hint_tab_completes = false))'
    flock /tmp/claude-1000/julia-review.lock bash -c 's=$(date +%s.%N)
        nice -n 19 timeout -s KILL 900 script -qec "$1" /dev/null < "$2" > "$3" 2>&1
        printf "\nS %s E %s\n" "$s" "$(date +%s.%N)" >> "$3"' _ \
        "$J --startup-file=no --trace-compile=$H/logs/$tag/trace-$i.jl --trace-compile-timing -e '$ex' -i --banner=no --project=$env" \
        logs/$tag/session-census.jl logs/$tag/census-$i.out
    echo "census $i | $(python3 -I $R/experiments/phase2-round/parse.py logs/$tag/census-$i.out)"
done
