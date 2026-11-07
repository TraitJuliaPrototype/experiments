#!/bin/bash
# E-283 (3): the code slot in a session (compiler §3.3). W-106's two workloads and TraitWorld's tests,
# each with JULIA_CODE_SLOT=1 and =0, one job at a time (niced): the wall time, and at exit the slot's
# counts (callers marked, kept, marks made final, slot misses resolved by the runtime). Each setting
# has a depot of its own, so TraitWorld's image is compiled with the setting's code; an untimed
# `using TraitWorld` compiles it first.
# Logs: experiments/unification/stack/logs/e283-<what>-slot<0|1>.log
# Usage: source env.sh; experiments/unification/stack/slot_session.sh julia-unified
R=$(cd "$(dirname "$0")/../../.." && pwd); T=$1
U=$R/experiments/unification; LOG=$U/stack/logs
J=$R/$T/julia
STAT='atexit(() -> println("slot stats: marks=", ccall(:jl_code_slot_stat, Csize_t, (Cint,), 0), " kept=", ccall(:jl_code_slot_stat, Csize_t, (Cint,), 1), " final=", ccall(:jl_code_slot_stat, Csize_t, (Cint,), 2), " misses=", ccall(:jl_code_slot_stat, Csize_t, (Cint,), 3)))'
run() {  # $1 label, $2 slot, $3 directory, $4 file
  local log=$LOG/e283-$1-slot$2.log t0 t1 rc
  t0=$(date +%s.%N)
  (cd "$3" && JULIA_DEPOT_PATH="$DEPOT$2:" JULIA_CODE_SLOT=$2 nice -n 10 "$J" --startup-file=no --project="$R/TraitWorld-unified" -e "$STAT; include(\"$4\")" > "$log" 2>&1)
  rc=$?; t1=$(date +%s.%N)
  printf '%-10s slot=%s exit %s wall %6.1f s  %s\n' "$1" "$2" "$rc" "$(echo "$t1 - $t0" | bc)" "$(grep -h 'slot stats' "$log" | tail -1)"
}
DEPOT=$(mktemp -d)/depot
echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"
for s in 1 0; do
  JULIA_DEPOT_PATH="$DEPOT$s:" JULIA_CODE_SLOT=$s nice -n 10 "$J" --startup-file=no --project="$R/TraitWorld-unified" -e 'using TraitWorld' > /dev/null 2>&1
  run columns $s "$U/workloads" "$U/workloads/columns.jl"
  run ode $s "$U/workloads" "$U/workloads/ode.jl"
  run traitworld $s "$R/TraitWorld-unified" "$R/TraitWorld-unified/test/runtests.jl"
done
echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"
