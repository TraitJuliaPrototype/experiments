#!/bin/bash
R=/home/hellmann/Repos/julia-trait-bound; J=$R/julia-1.13/julia; L=/tmp/claude-1000/julia-review.lock
cd $R/forks; export JULIA_PKG_OFFLINE=true
echo "-- -e, no REPL"; flock $L nice -n 10 $J --startup-file=no --project=env_forks -e '@time "using all four" using CSV, DataFrames, Statistics, Dates' 2>&1 | tail -2
echo "-- -e, REPL first"; flock $L nice -n 10 $J --startup-file=no --project=env_forks -e 'using REPL; @time "using all four" using CSV, DataFrames, Statistics, Dates' 2>&1 | tail -2
echo "-- interactive REPL on a pty"
printf '%s\n' '@time "using all four" using CSV, DataFrames, Statistics, Dates' 'exit()' > $TMPDIR/fi.jl
flock $L nice -n 10 script -qec "$J --startup-file=no -i --banner=no --project=env_forks" /dev/null < $TMPDIR/fi.jl 2>&1 | tr -d '\r' | grep -a "using all four" | tail -1
echo "-- upstream, interactive"
flock $L nice -n 10 script -qec "$J --startup-file=no -i --banner=no --project=env_upstream" /dev/null < $TMPDIR/fi.jl 2>&1 | tr -d '\r' | grep -a "using all four" | tail -1
