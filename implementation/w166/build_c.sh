#!/bin/bash
# W-166, last part (E-509): bash build_c.sh <app> [project] -- ../w135/build.sh with these variables:
#   DRIVER=<dir>   the directory of juliac-buildscript.jl (default: the tree's test/trimming)
#   DEPOT=<dir>    a depot stacked before the shared one, for the images (default: none, the shared depot alone)
#   IMAGES=1       before the build, write the program's package images with the build's own Julia and flags
#                  (a process without output, as the session of ../w135/run_warn.sh did): the build then loads
#                  the packages from their images instead of running their top-level code. PKGS overrides the
#                  list of packages (default by app: below). IMAGES=0 builds as ../w135/build.sh does.
#   (always) a line "from source: …": the program's packages that have no valid image for the build's Julia
#   XFLAGS=<flags>  more options for the build's process (e.g. --compiled-modules=no: every package from source)
#   TW=<tree>      the library's tree named in the log's header (default TraitWorld)
# TRIM, NAME, JULIA_TREE, VERIFY and the apps' variables as for ../w135/build.sh. Log: logs/w166c-<name>.build.log;
# the image step's log: logs/w166c-<name>.images.log. Memory guard 4 GB; no core file.
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
[ -n "${DEPOT:-}" ] && { mkdir -p "$DEPOT"; export JULIA_DEPOT_PATH=$DEPOT:$TW_ROOT/.julia-depot:; }
A=$H/../w135/apps
app=$1; name=w166c-${NAME:-$1}; proj=${2:-$H/../w156/env_demo}; T=${JULIA_TREE:-julia-next}; J=$R/$T/julia
TR=${DRIVER:-$R/$T/test/trimming}
O=$H/out; LOG=$H/logs/$name.build.log; mkdir -p "$O"
LIB=$($J --startup-file=no -e 'print(joinpath(Sys.BINDIR, "..", "lib"))')
CFG="$J --startup-file=no -e include(joinpath(Sys.BINDIR,Base.DATAROOTDIR,\"julia\",\"julia-config.jl\")) --"
rev() { git -C "$R/$1" log -1 --format=%h; }
case $app in
  table)  P="TraitWorld TraitCSV TraitTables" ;;
  plot)   P="TraitWorld TraitMakie" ;;
  report) [ "${REPORT_PLAIN:-0}" = 1 ] && P="PlainTables PlainPlots" || P="TraitWorld TraitCSV TraitTables TraitMakie" ;;
  ode)    [ "${ODE_PLAIN:-0}" = 1 ] && P="PlainODE" || P="TraitWorld TraitDifferentialEquations" ;;
  *)      P="TraitWorld" ;;
esac
P=${PKGS:-$P}
echo "# W-166c $app $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $T $(rev $T) ${TW:-TraitWorld} $(rev ${TW:-TraitWorld}) project ${proj#$R/} trim=${TRIM:-safe} images=${IMAGES:-1} driver=${TR#$R/} depot=${DEPOT:+${DEPOT#$R/}:}shared ${XFLAGS:-}" > "$LOG"
if [ "${IMAGES:-1}" = 1 ]; then
  t0=$(date +%s)
  nice -n 10 env JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 $J -t 1 -J $LIB/julia/sys.so --startup-file=no \
    --history-file=no --project=$proj -e 'Base.Precompilation.precompilepkgs(String.(ARGS); timing = true)' $P \
    > "$H/logs/$name.images.log" 2>&1
  echo "images: exit $? after $(( $(date +%s) - t0 )) s ($P)" | tee -a "$LOG"
fi
# which of the program's packages the build would load from source (no valid image for this Julia and flags):
# their top-level code then runs in the build's process, where no package's `__init__` has run
$J -t 1 -J $LIB/julia/sys.so --startup-file=no --project=$proj -e '
  s = filter(p -> !Base.isprecompiled(Base.identify_package(p)), ARGS)
  println("from source: ", isempty(s) ? "none" : join(s, " "))' $P 2>&1 | tee -a "$LOG"
start=$(date +%s)
setsid nice -n 10 env JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 \
  $J -t 1 -J $LIB/julia/sys.so --startup-file=no --history-file=no --project=$proj --output-o $O/$name-o.a --output-incremental=no \
  --strip-ir --strip-metadata --experimental ${XFLAGS:-} --trim=${TRIM:-safe} $TR/juliac-buildscript.jl $A/$app.jl --output-exe true >> "$LOG" 2>&1 &
pid=$!
while kill -0 $pid 2>/dev/null; do
  avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  if [ "$avail" -lt 4096 ]; then echo "WATCHDOG: $avail MB" >> "$LOG"; kill -TERM -$pid; sleep 5; kill -KILL -$pid 2>/dev/null; exit 99; fi
  sleep 2
done
wait $pid; rc=$?
echo "object: exit $rc after $(( $(date +%s) - start )) s" | tee -a "$LOG"
[ $rc -eq 0 ] || { rm -f $O/$name-o.a; exit $rc; }
cc -o $O/$name -Wl,--whole-archive $O/$name-o.a -Wl,--no-whole-archive -lm -L$LIB -L$LIB/julia -Wl,-rpath,$LIB -Wl,-rpath,$LIB/julia $($CFG --ldflags --ldlibs) -ljulia-internal >> "$LOG" 2>&1
echo "link: exit $?, $(stat -c %s $O/$name 2>/dev/null) bytes" | tee -a "$LOG"
rm -f $O/$name-o.a
