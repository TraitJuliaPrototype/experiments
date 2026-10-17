#!/usr/bin/env bash
# Build a trimmed executable with the patched 1.13.2 and its test copy of the juliac build script.
#   ./build.sh plot_app   (alone on the machine; memory guard: kill below 4 GB available)
set -u
cd "$(dirname "$0")"
app=$1
J=../../julia-1.13/julia
TR=../../julia-1.13/test/trimming
LIB=$($J --startup-file=no -e 'print(joinpath(Sys.BINDIR, "..", "lib"))')
CFG="$J --startup-file=no -e include(joinpath(Sys.BINDIR,Base.DATAROOTDIR,\"julia\",\"julia-config.jl\")) --"
start=$(date +%s)
setsid nice -n 10 env JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_LOAD_PATH="${AOT_LOAD_PATH:-$TMPDIR/env_main_TraitMakie:@stdlib}" \
  $J -t 1 -J $LIB/julia/sys.so --startup-file=no --history-file=no --output-o $app-o.a --output-incremental=no \
  --strip-ir --strip-metadata --experimental --trim=${TRIM:-unsafe-warn} $TR/juliac-buildscript.jl $PWD/$app.jl --output-exe true > $app.build.log 2>&1 &
pid=$!
while kill -0 $pid 2>/dev/null; do
  avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  if [ "$avail" -lt 4096 ]; then echo "WATCHDOG: $avail MB" >> $app.build.log; kill -TERM -$pid; sleep 5; kill -KILL -$pid 2>/dev/null; exit 99; fi
  sleep 5
done
wait $pid; rc=$?
echo "object: exit $rc after $(( $(date +%s) - start )) s" | tee -a $app.build.log
[ $rc -eq 0 ] || exit $rc
cc -o $app -Wl,--whole-archive $app-o.a -Wl,--no-whole-archive -lm -L$LIB -L$LIB/julia -Wl,-rpath,$LIB -Wl,-rpath,$LIB/julia $($CFG --ldflags --ldlibs) -ljulia-internal >> $app.build.log 2>&1
echo "link: exit $?, $(stat -c %s $app 2>/dev/null) bytes" | tee -a $app.build.log
