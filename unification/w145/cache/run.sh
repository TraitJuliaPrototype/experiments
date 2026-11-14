#!/bin/bash
# W-145, part 2 (G-3): the cache workloads. For each form and case, a warm-up process (it writes the
# images) and N fresh processes, one thread, niced: the marks, and the compiles after the loads by the
# package whose method it is (the last run's).
#     bash run.sh [tag] [N] [dirs…]     -> logs/cache[-tag].log
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../../.." && pwd); source "$R/env.sh"
tag=${1:+-$1}; N=${2:-3}; shift; shift
J=$R/julia-unified/julia; LOG=$H/logs/cache$tag.log
DEPOT=$H/depot
rev() { git -C "$R/$1" log -1 --format=%h; }
[ -d "$H/pkgs" ] || "$J" --startup-file=no "$H/gen.jl" "$R/TraitWorld-unified"
echo "# W-145 cache $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified $(rev julia-unified) TraitWorld $(rev TraitWorld-unified) | N=$N, one thread" | tee "$LOG"
dirs=${*:-$(ls "$H/pkgs")}
for d in $dirs; do
  for r in $(seq 0 $N); do
    s=$(date +%s.%N)
    out=$(JULIA_DEPOT_PATH="$DEPOT:" JULIA_PKG_OFFLINE=true nice -n 10 "$J" -t 1 --startup-file=no --project="$H/pkgs/$d/env" "$H/session.jl" "$H/pkgs/$d" 2>&1)
    e=$(date +%s.%N)
    [ $r = 0 ] && continue
    echo "$d run $r: wall $(echo "$e - $s" | bc | cut -c1-5) s | $(echo "$out" | grep '^MARKS' | cut -c7-)" | tee -a "$LOG"
    [ $r = $N ] && echo "$out" | grep '^CLASS' | sed "s/^CLASS/$d class/" | tee -a "$LOG"
    echo "$out" | grep -v '^MARKS\|^CLASS' | head -5 | sed "s/^/$d !! /" | tee -a "$LOG"
  done
done
