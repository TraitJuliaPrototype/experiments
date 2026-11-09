#!/bin/bash
# E-337: `IO` a closed abstract type with a contract, the eraser `IOContext{IO}`, the forks' DataFrames erasing at
# its display entries (traits §9b; the user, 2026-11-09). After the battery (stack/battery.sh, label w337):
#   1. the ports' environments precompiled;
#   2. E-328's workloads on both builds against vanilla (`raw`, and `split` against the hand-routed proxy);
#   3. the sessions, a warm-up and 3 runs each, the unchanged early build's forms interleaved as the load's control:
#      f-early, f-unified (the goal's task), forks-early, forks-unified (the `show` step, 164's case), d-unified, t-unified;
#   4. one traced forks session: the `show` steps' compiles;
#   5. the forks' digests and the REPL transcript (scripts/check_session.sh).
# PYENV must name the Python of E-284. Logs: logs/e337-*.log here, the sessions' in logs/<part>-w337.log,
# the traced session in ../e323/session-traced-w337.txt.
set -u
: "${PYENV:?set PYENV to the Python of E-284}"
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); E=$R/experiments/unification
source "$R/env.sh"
L=${1:-w337}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
echo "unified $(git -C "$R/julia-unified" rev-parse --short HEAD), TraitWorld $(git -C "$R/TraitWorld-unified" rev-parse --short HEAD), forks-unified $(git -C "$R/forks-unified" rev-parse --short HEAD)"
step "1 precompile"
PCLOG=$H/logs/e337-precompile-$L.log; : > "$PCLOG"
pc() { local s=$(date +%s.%N); nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' >> "$PCLOG" 2>&1; echo "$(echo "$(date +%s.%N) - $s" | bc) s $1" >> "$PCLOG"; }
pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
pc "$R/TraitReport-unified/env_t"; pc "$R/TraitReport-unified/env_pt"; pc "$R/TraitReport-unified/env_fu"
pc "$R/TraitDifferentialEquations-unified"
(cd "$R/experiments/ttfx" && nice -n 10 "$U" --startup-file=no --project="$H/env_d_unified" -e "using TraitDifferentialEquations, TraitMakie, TraitWorld" >> "$PCLOG" 2>&1)
(unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks")
grep -E '^[0-9.]+ s |WARNING|refus' "$PCLOG" | cut -c1-160
step "2 E-328's workloads"
(cd "$R" && bash experiments/unification/e328/run.sh "-$L" > /dev/null 2>&1; echo "e328 exit $?")
step "3 sessions, a warm-up and 3 runs each"
for p in f-early-$L f-unified-$L forks-early-$L forks-unified-$L d-unified-$L t-unified-$L; do
    bash "$H/run.sh" "$p" 3 > /dev/null 2>&1
    grep -E '^(1|2|3|fk-patched [123]|[123] |startup)' "$H/logs/$p.log" | grep -o -E 'imports [0-9.]+|read [0-9.]+|show [0-9.]+|3_read_show [0-9.]+|wall [0-9.]+|total [0-9.]+' | tr '\n' ' '; echo " $p"
done
step "4 the traced forks session"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JFLAGS="--trace-compile=stderr --trace-compile-timing" PATCHED=$U bash scripts/measure_session.sh 1 fk-patched > "$E/e323/session-traced-$L.txt" 2>&1; cp "${TMPDIR:-/tmp}/forks_session/fk-patched.out" "$E/e323/session-traced-$L.out")
grep -c "precompile(" "$E/e323/session-traced-$L.txt"
step "5 checks"
(cd "$R/forks-unified" && unset JULIA_DEPOT_PATH && JULIA_LOCK=$H/.lock bash scripts/check_session.sh "$U" 2>&1 | tail -3)
step "done"
