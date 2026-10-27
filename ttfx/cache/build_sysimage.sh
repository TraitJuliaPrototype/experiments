#!/bin/bash
# E-170, the second ceiling: a system image of stock 1.13.2 with OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock and
# CairoMakie (env_up) and the statements of the NoSpecialize session that do not name Main (cache/S-sysimage-statements.jl).
# Alone, niced, killed below 4 GB available.   bash cache/build_sysimage.sh   -> out/S-sys.so
cd "$(dirname "$0")/.."; H=$PWD
JS=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia
export JULIA_NUM_PRECOMPILE_TASKS=1 JULIA_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_GC_AUTO=false JULIA_DEPOT_PATH=$H/depot-S:$HOME/.julia: JULIA_LOAD_PATH="$H/env_up:$H/env_pc:@stdlib" OPENBLAS_NUM_THREADS=1
setsid nice -n 19 $JS --startup-file=no -e '
using PackageCompiler
t = @elapsed create_sysimage(["OrdinaryDiffEqTsit5", "OrdinaryDiffEqRosenbrock", "CairoMakie"]; sysimage_path = "out/S-sys.so",
    project = "env_up", precompile_statements_file = get(ENV, "SYS_STATEMENTS", "") == "" ? String[] : ENV["SYS_STATEMENTS"])
println("sysimage s=", round(t; digits = 1), " size MB=", round(filesize("out/S-sys.so") / 2^20; digits = 1))' > logs/cache/S-sysimage.log 2>&1 &
watchlog=logs/cache/S-sysimage-mem.log; : > $watchlog
pid=$!
while kill -0 $pid 2>/dev/null; do
  avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  if [ "$avail" -lt ${GUARD_MB:-4096} ]; then echo "WATCHDOG: MemAvailable ${avail} MB, killing" >> $watchlog; kill -TERM -$pid; sleep 5; kill -KILL -$pid 2>/dev/null; exit 99; fi
  echo "$(date +%T) avail ${avail} MB" >> $watchlog; sleep 10
done
wait $pid; rc=$?; echo "rc=$rc" >> logs/cache/S-sysimage.log; tail -3 logs/cache/S-sysimage.log
