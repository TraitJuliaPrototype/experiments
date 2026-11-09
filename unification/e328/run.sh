#!/bin/bash
# E-328: the stream erased as IOContext{IO} against IOContext{IOBuffer}, on vanilla v1.13.2 (with upstream
# CSV and DataFrames) and on the unified build (Base only). `source env.sh` first. A few minutes.
set -e
H=$(cd "$(dirname "$0")" && pwd)
R=$(cd "$H/../../.." && pwd)
export JULIA_PKG_OFFLINE=true DATA=$R/forks-unified/data
nice -n 19 "$R/julia-vanilla/julia" --startup-file=no --project="$R/forks-unified/env_upstream" \
    "$H/erase_io.jl" pkgs 2>&1 | tee "$H/logs/e328-vanilla.log"
nice -n 19 "$R/julia-unified/julia" --startup-file=no "$H/erase_io.jl" 2>&1 | tee "$H/logs/e328-unified.log"
