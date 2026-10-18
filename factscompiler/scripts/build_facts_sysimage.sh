#!/bin/bash
# A system image of the patched build with Base and the standard libraries compiled by facts
# (JULIA_COMPILE_BY_FACTS=1 while it is built: the image keeps the mode on). The steps are
# sysimage.mk's sysbase and sys steps, written to OUT; basecompiler.so is the normal build's,
# since the compiler's own code is compiled plainly in either mode.
# Use: julia -J $OUT/sys.so, with a depot of its own (JULIA_DEPOT_PATH=<dir>:).
set -e
J13=/home/hellmann/Repos/julia-trait-bound/julia-1.13
OUT=${OUT:-$J13/usr/lib/julia/facts}
mkdir -p "$OUT"
LIB=$J13/usr/lib/julia
export JULIA_COMPILE_BY_FACTS=1 JULIA_BINDIR=$J13/usr/bin JULIA_NUM_THREADS=1
link() { g++ -march=native -mtune=native -m64 -shared -fPIC -L$LIB -L$J13/usr/lib -o "$2" -Wl,--whole-archive "$1" -Wl,--no-whole-archive -ljulia-internal -ljulia; }
watch() {  # run "$@" niced, killed below 4 GB available
  setsid nice -n 10 "$@" & local pid=$!
  while kill -0 $pid 2>/dev/null; do
    avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
    if [ "$avail" -lt 4096 ]; then echo "WATCHDOG: MemAvailable ${avail} MB, killing"; kill -TERM -$pid; sleep 5; kill -KILL -$pid 2>/dev/null; exit 99; fi
    sleep 10
  done
  wait $pid
}
cd $J13/base
echo "sysbase (facts) $(date +%T)"
watch $J13/usr/bin/julia -g1 -O3 -C native --output-o "$OUT/sysbase-o.a" --startup-file=no --warn-overwrite=yes --depwarn=error \
  --sysimage $LIB/basecompiler.so sysimg.jl --buildroot ./ --dataroot ../usr/share/
link "$OUT/sysbase-o.a" "$OUT/sysbase.so"
echo "sys (facts) $(date +%T)"
JULIA_LOAD_PATH='@stdlib' JULIA_PROJECT= JULIA_DEPOT_PATH=':' watch $J13/usr/bin/julia -O3 -C native --output-o "$OUT/sys-o.a" \
  --startup-file=no --warn-overwrite=yes --depwarn=error --sysimage "$OUT/sysbase.so" $J13/contrib/generate_precompile.jl 1
link "$OUT/sys-o.a" "$OUT/sys.so"
rm -f "$OUT/sysbase-o.a" "$OUT/sys-o.a"
echo "done $(date +%T): $OUT/sys.so"
