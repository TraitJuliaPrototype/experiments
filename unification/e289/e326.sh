#!/bin/bash
# E-326: an image holds the code a facts run-time site reaches whatever the values (compiler §9, mine):
# `unified` + 6767b03893 (branch e326 of julia-unified). E-322 (labels -w322, TraitWorld `e322` bf42928 on 23022b0ec7)
# and E-324 (-w324, TraitWorld plain 1745fc6) are the controls.
#   part a (label $1, default w326a): TraitWorld `e322` (compiled by facts);
#   part b (label $2, default w326b): TraitWorld `e326b` dbce5f7 (the check code's closures as loops).
# Each part: the environments precompiled (timed, logs/e326-precompile-<label>.log); TraitWorld's image size;
# TraitWorld's tests; the compiles of TraitWorld's in the goal's task, setting D and (t) (traced, e326/trace-*);
# E-289's sessions. Part a also: the gates; TDE's suite. Part b also: TDE's suite.
# Fixed after the run of 2026-11-09: the sessions' summary now reads (t)'s `startup` lines (they were missing in
# logs/e326-run.log), and the traced setting D's PNG directory is created (the census stopped at its first PNG).
# PYENV must name the Python of E-284. Logs: logs/e326-*.log here, the traces in ../e326/, the sessions' in logs/.
set -u
: "${PYENV:?set PYENV to the Python of E-284}"
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
LA=${1:-w326a}; LB=${2:-w326b}; U=$R/julia-unified/julia; E=$R/experiments/unification; T=$E/e326
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
CSV=$R/experiments/interfaces/App/data/sample.csv; OUT=$H/out; mkdir -p "$OUT" "$T" "$OUT/png-e326"; export MPLCONFIGDIR=$OUT/mpl
TWD=${JULIA_DEPOT_PATH%%:*}/compiled/v1.13/TraitWorld
echo "unified $(git -C "$R/julia-unified" rev-parse --short HEAD) ($(git -C "$R/julia-unified" rev-parse --abbrev-ref HEAD))"

precompile_all() {   # label
    local PCLOG=$H/logs/e326-precompile-$1.log; : > "$PCLOG"
    pc() { local s=$(date +%s.%N); nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' >> "$PCLOG" 2>&1; echo "$(echo "$(date +%s.%N) - $s" | bc) s $1" >> "$PCLOG"; }
    pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
    pc "$R/TraitReport-unified/env_t"; pc "$R/TraitReport-unified/env_pt"; pc "$R/TraitReport-unified/env_fu"
    pc "$R/TraitDifferentialEquations-unified"
    (cd "$R/experiments/ttfx" && nice -n 10 "$U" --startup-file=no --project="$H/env_d_unified" -e "using TraitDifferentialEquations, TraitMakie, TraitWorld" >> "$PCLOG" 2>&1)
    (unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks")
    grep -E '^[0-9.]+ s |✓ TraitWorld$|✓ TraitWorld |WARNING' "$PCLOG" | cut -c1-160
    echo "TraitWorld's image: $(ls -t "$TWD"/*.so | head -1 | xargs stat -c %s) bytes"
}
traces() {   # label
    (cd "$R/TraitReport-unified" && nice -n 10 "$U" --startup-file=no --project=env_fu --trace-compile="$T/trace-goal-$1.jl" --trace-compile-timing scripts/report_forks.jl "$CSV" "$OUT/f-trace-$1.png" > /dev/null 2>&1)
    (cd "$R/experiments/ttfx" && WL_D=trait WL_SHAPE=matched WL_ORDER=A WL_SPEC=auto JULIA_NUM_THREADS=1 nice -n 10 "$U" --startup-file=no --project="$H/env_d_unified" --trace-compile="$T/trace-d-$1.jl" --trace-compile-timing workload_d.jl "$OUT/png-e326" > /dev/null 2>&1)
    (cd "$R/TraitReport-unified" && nice -n 10 "$U" --startup-file=no --project=env_t --trace-compile="$T/trace-t-$1.jl" --trace-compile-timing scripts/report_tables.jl "$CSV" "$OUT/t-trace-$1.png" > /dev/null 2>&1)
    for w in goal d t; do f=$T/trace-$w-$1.jl
        echo "$w: $(grep -c . "$f") compiles, $(grep -c 'TraitWorld\.' "$f") of TraitWorld's, $(grep 'TraitWorld\.' "$f" | grep -o '^#= *[0-9.]* ms' | grep -o '[0-9.]*' | paste -sd+ | sed 's/^$/0/' | bc) ms"
    done
}
sessions() {   # label
    for p in f-unified-$1 forks-unified-$1 d-unified-$1 t-unified-$1; do bash "$H/run.sh" "$p" 3 > /dev/null 2>&1; grep -E '^(1|2|3|fk-patched [123]|[123] |startup)' "$H/logs/$p.log" | grep -o -E 'wall [0-9.]+|total [0-9.]+' | tr '\n' ' '; echo " $p"; done
}
tests() {   # label
    (cd "$R/TraitWorld-unified" && nice -n 10 "$U" --startup-file=no --project=. test/runtests.jl > "$H/logs/e326-traitworld-$1.log" 2>&1; echo "traitworld exit $?")
    (cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e326-tde-test-$1.log" 2>&1; echo "tde exit $?")
}

for part in a b; do
    if [ $part = a ]; then L=$LA; git -C "$R/TraitWorld-unified" checkout -q e322; else L=$LB; git -C "$R/TraitWorld-unified" checkout -q e326b; fi
    step "$part. TraitWorld at $(git -C "$R/TraitWorld-unified" rev-parse --short HEAD) ($(git -C "$R/TraitWorld-unified" rev-parse --abbrev-ref HEAD)), label $L"
    step "$part.1 precompile"; precompile_all "$L"
    step "$part.2 tests"; tests "$L"
    if [ $part = a ]; then
        step "a.2b gates"
        bash "$E/gates/run_all.sh" julia-unified 'm[12]_*' > "$H/logs/e326-gates-m-$L.log" 2>&1; tail -1 "$H/logs/e326-gates-m-$L.log"
        bash "$E/gates/run_all.sh" julia-unified '[nf]*' > "$H/logs/e326-gates-nf-$L.log" 2>&1; tail -1 "$H/logs/e326-gates-nf-$L.log"
        grep -h -A6 '^FAIL' "$H/logs/e326-gates-m-$L.log" "$H/logs/e326-gates-nf-$L.log" | head -20
    fi
    step "$part.3 traces"; traces "$L"
    step "$part.4 sessions"; sessions "$L"
done
step "done"
