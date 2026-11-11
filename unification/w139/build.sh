#!/bin/bash
# E-364: bash build.sh <app> [project] -- a trimmed executable of apps/<app>.jl with julia-unified's
# test copy of the juliac build script. TRIM=safe (default) | unsafe | unsafe-warn. Memory guard: 4 GB.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
app=$1; name=${NAME:-$1}; proj=${2:-$R/TraitWorld-unified}; T=${JULIA_TREE:-julia-unified}; J=$R/$T/julia; TR=$R/$T/test/trimming
O=$H/out; LOG=$H/logs/${NAME:-$1}.build.log; mkdir -p "$O"
LIB=$($J --startup-file=no -e 'print(joinpath(Sys.BINDIR, "..", "lib"))')
CFG="$J --startup-file=no -e include(joinpath(Sys.BINDIR,Base.DATAROOTDIR,\"julia\",\"julia-config.jl\")) --"
rev() { git -C "$R/$1" log -1 --format=%h; }
echo "# E-364 $app $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $T $(rev $T) TraitWorld-unified $(rev TraitWorld-unified) trim=${TRIM:-safe}" > "$LOG"
start=$(date +%s)
setsid nice -n 10 env JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 ${AOT_LOAD_PATH:+JULIA_LOAD_PATH=$AOT_LOAD_PATH} \
  $J -t 1 -J $LIB/julia/sys.so --startup-file=no --history-file=no --project=$proj --output-o $O/$name-o.a --output-incremental=no \
  --strip-ir --strip-metadata --experimental --trim=${TRIM:-safe} $TR/juliac-buildscript.jl $H/apps/$app.jl --output-exe true >> "$LOG" 2>&1 &
pid=$!
while kill -0 $pid 2>/dev/null; do
  avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  if [ "$avail" -lt 4096 ]; then echo "WATCHDOG: $avail MB" >> "$LOG"; kill -TERM -$pid; sleep 5; kill -KILL -$pid 2>/dev/null; exit 99; fi
  sleep 2
done
wait $pid; rc=$?
echo "object: exit $rc after $(( $(date +%s) - start )) s" | tee -a "$LOG"
[ $rc -eq 0 ] || exit $rc
cc -o $O/$name -Wl,--whole-archive $O/$name-o.a -Wl,--no-whole-archive -lm -L$LIB -L$LIB/julia -Wl,-rpath,$LIB -Wl,-rpath,$LIB/julia $($CFG --ldflags --ldlibs) -ljulia-internal >> "$LOG" 2>&1
echo "link: exit $?, $(stat -c %s $O/$name 2>/dev/null) bytes" | tee -a "$LOG"
