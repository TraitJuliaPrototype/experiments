#!/bin/bash
# W-19: bash build_app.sh <tree> <app.jl> <name> -- a trimmed build of a plain program (no package) with <tree>'s
# juliac build script, as ../w158/build_app.sh does. Log: logs/<name>.build.log; the binary in out/; no core file.
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
export JULIA_DEPOT_PATH=$R/.julia-depot/agent-depots/w19:$R/.julia-depot: JULIA_PKG_OFFLINE=true
T=$1; app=$(cd "$(dirname "$2")" && pwd)/$(basename "$2"); name=$3; proj=$H/env_empty
J=$R/$T/julia; TR=$R/$T/test/trimming; O=$H/out; LOG=$H/logs/$name.build.log; mkdir -p $O
LIB=$($J --startup-file=no -e 'print(joinpath(Sys.BINDIR, "..", "lib"))')
CFG="$J --startup-file=no -e include(joinpath(Sys.BINDIR,Base.DATAROOTDIR,\"julia\",\"julia-config.jl\")) --"
echo "# W-19 $app $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $T $(git -C $R/$T log -1 --format=%h) trim=${TRIM:-safe}" > $LOG
nice -n 10 $J -t 1 -J $LIB/julia/sys.so --startup-file=no --history-file=no --project=$proj --output-o $O/$name-o.a --output-incremental=no \
  --strip-ir --strip-metadata --experimental --trim=${TRIM:-safe} $TR/juliac-buildscript.jl $app --output-exe true >> $LOG 2>&1; rc=$?
echo "object: exit $rc" | tee -a $LOG
[ $rc -eq 0 ] && cc -o $O/$name -Wl,--whole-archive $O/$name-o.a -Wl,--no-whole-archive -lm -L$LIB -L$LIB/julia -Wl,-rpath,$LIB -Wl,-rpath,$LIB/julia $($CFG --ldflags --ldlibs) -ljulia-internal >> $LOG 2>&1 && echo "link: $(stat -c %s $O/$name) bytes" | tee -a $LOG
rm -f $O/$name-o.a
grep -h "Trim verify finished" $LOG
