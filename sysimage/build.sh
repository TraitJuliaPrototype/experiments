#!/bin/bash
# build the TraitWorld system image under a memory watchdog (kill below 4 GB available)
OUT=${OUT:-$TMPDIR/systw}; mkdir -p "$OUT"; SRC=$(cd "$(dirname "$0")" && pwd); cd "$OUT"
R=/home/hellmann/Repos/julia-trait-bound/julia-1.13
export JULIA_LOAD_PATH="$TMPDIR/twtestenv13p:@stdlib" JULIA_NUM_THREADS=1 JULIA_PKG_OFFLINE=true
s=$(date +%s)
: > build.log
setsid nice -n 10 $R/julia --startup-file=no --sysimage $R/usr/lib/julia/sys.so -C native --output-o systw-o.a.tmp $SRC/build.jl >> build.log 2>&1 &
pid=$!
peak=0
while kill -0 $pid 2>/dev/null; do
  avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  if [ "$avail" -lt 4096 ]; then echo "WATCHDOG: MemAvailable ${avail} MB, killing" >> build.log; kill -TERM -$pid; sleep 5; kill -KILL -$pid 2>/dev/null; exit 99; fi
  sleep 5
done
wait $pid; rc=$?; echo "output rc $rc after $(( $(date +%s) - s )) s" >> build.log
[ $rc = 0 ] || exit $rc
mv systw-o.a.tmp systw-o.a
c++ -shared -fPIC -L$R/usr/lib/julia -L$R/usr/lib -Wl,--whole-archive systw-o.a -Wl,--no-whole-archive -ljulia-internal -ljulia -o systw.so >> build.log 2>&1
echo "link rc $? after $(( $(date +%s) - s )) s" >> build.log
