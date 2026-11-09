#!/bin/bash
# E-329: traits closed after load (W-129 (a)) on `unified` with the change, TraitWorld with `@closed_after_load`.
# No port opts in, so the sessions should equal E-326's. After the battery (stack/battery.sh, label w329):
# the ports' environments precompiled (none refuses a method); TDE's suite; one run of E-289's four sessions.
# PYENV must name the Python of E-284. Logs: logs/e329-*.log here, the sessions' in logs/<part>-w329.log.
set -u
: "${PYENV:?set PYENV to the Python of E-284}"
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
L=${1:-w329}; U=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true
step() { echo "== $(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))"; }
echo "unified $(git -C "$R/julia-unified" rev-parse --short HEAD), TraitWorld $(git -C "$R/TraitWorld-unified" rev-parse --short HEAD)"
step "1 precompile"
PCLOG=$H/logs/e329-precompile-$L.log; : > "$PCLOG"
pc() { local s=$(date +%s.%N); nice -n 10 "$U" --startup-file=no --project="$1" -e 'using Pkg; Pkg.precompile()' >> "$PCLOG" 2>&1; echo "$(echo "$(date +%s.%N) - $s" | bc) s $1" >> "$PCLOG"; }
pc "$R/TraitWorld-unified"; pc "$R/experiments/unification"
pc "$R/TraitReport-unified/env_t"; pc "$R/TraitReport-unified/env_pt"; pc "$R/TraitReport-unified/env_fu"
pc "$R/TraitDifferentialEquations-unified"
(cd "$R/experiments/ttfx" && nice -n 10 "$U" --startup-file=no --project="$H/env_d_unified" -e "using TraitDifferentialEquations, TraitMakie, TraitWorld" >> "$PCLOG" 2>&1)
(unset JULIA_DEPOT_PATH; pc "$R/forks-unified/env_forks")
grep -E '^[0-9.]+ s |WARNING|refus' "$PCLOG" | cut -c1-160
step "2 TDE's suite"
(cd "$R/TraitDifferentialEquations-unified" && nice -n 10 "$U" --startup-file=no --project=. -e 'using Pkg; Pkg.test()' > "$H/logs/e329-tde-test-$L.log" 2>&1; echo "tde exit $?")
step "3 sessions, one run each"
for p in f-unified-$L forks-unified-$L d-unified-$L t-unified-$L; do
    bash "$H/run.sh" "$p" 1 > /dev/null 2>&1
    grep -E '^(1|2|3|fk-patched [123]|[123] |startup)' "$H/logs/$p.log" | grep -o -E 'wall [0-9.]+|total [0-9.]+' | tr '\n' ' '; echo " $p"
done
step "done"
