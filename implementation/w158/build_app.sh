#!/bin/bash
# W-158: bash build_app.sh <tree> <app.jl> <name> [project] -- a trimmed build of any app file (W-166's build_app.sh,
# its logs in this directory). Log: logs/<name>.build.log; no core file.
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
T=$1; app=$(cd "$(dirname "$2")" && pwd)/$(basename "$2"); name=$3; proj=${4:-$R/TraitWorld}
J=$R/$T/julia; TR=$R/$T/test/trimming; O=$H/out; LOG=$H/logs/$name.build.log; mkdir -p $O
LIB=$($J --startup-file=no -e 'print(joinpath(Sys.BINDIR, "..", "lib"))')
CFG="$J --startup-file=no -e include(joinpath(Sys.BINDIR,Base.DATAROOTDIR,\"julia\",\"julia-config.jl\")) --"
echo "# W-166 $app $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $T $(git -C $R/$T log -1 --format=%h) TraitWorld $(git -C $R/TraitWorld log -1 --format=%h) trim=${TRIM:-safe}" > $LOG
nice -n 10 env JULIA_PKG_OFFLINE=true $J -t 1 -J $LIB/julia/sys.so --startup-file=no --history-file=no --project=$proj --output-o $O/$name-o.a --output-incremental=no \
  --strip-ir --strip-metadata --experimental --trim=${TRIM:-safe} $TR/juliac-buildscript.jl $app --output-exe true >> $LOG 2>&1; rc=$?
echo "object: exit $rc" | tee -a $LOG
[ $rc -eq 0 ] && cc -o $O/$name -Wl,--whole-archive $O/$name-o.a -Wl,--no-whole-archive -lm -L$LIB -L$LIB/julia -Wl,-rpath,$LIB -Wl,-rpath,$LIB/julia $($CFG --ldflags --ldlibs) -ljulia-internal >> $LOG 2>&1 && echo "link: $(stat -c %s $O/$name) bytes" | tee -a $LOG
rm -f $O/$name-o.a
