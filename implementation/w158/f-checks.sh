#!/bin/bash
# W-158, fourth part (E-510): the checks of a Julia tree with the library at wt/w158b-tw, one after another, one Julia
# job at a time, niced; no core files. Logs logs/f-<what>-<label>.log.
#     bash f-checks.sh <label> [tree] [step ...]      steps: gates base library port tables makie builds small apps sessions
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh" > /dev/null; R=$TW_ROOT
L=$1; T=${2:-wt/w158-julia}; shift 2 2>/dev/null; STEPS=${@:-gates base library port tables makie builds small apps sessions}
J=$R/$T/julia; P=$R/wt/w158b-tw; rev() { git -C "$R/$1" log -1 --format=%h; }
hdr() { echo "# W-158 f-$1 $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $T $(rev $T) library wt/w158b-tw $(rev wt/w158b-tw) TDE $(rev TraitDifferentialEquations)"; }
for s in $STEPS; do
  LOG=$H/logs/f-$s-$L.log
  case $s in
    gates)   { hdr $s; LIB=wt/w158b-tw bash $R/experiments/implementation/gates/run_all.sh $T 2>&1 | grep -E '^(FAIL|gates:|stage gates:)|^ ' ; } > $LOG 2>&1 ;;
    base)    { hdr $s; for t in core subtype Compiler/inline Compiler/inference; do
                 (cd $R/$T/test && nice -n 10 $J --startup-file=no -e 'Base.runtests([ARGS[1]]; ncores = 1)' $t > /tmp/claude-harvest/f-base.out 2>&1)
                 echo "$t: exit $? $(grep -E 'SUCCESS|FAILURE' /tmp/claude-harvest/f-base.out | tail -1)"; done; } > $LOG 2>&1 ;;
    library) { hdr $s; (cd $P && nice -n 10 $J -t 1 --startup-file=no --project=. -e 'using TraitWorld; include("test/runtests.jl")') 2>&1;
               echo "exit $?"; } > $LOG 2>&1; echo "testsets $(grep -c '^Test Summary' $LOG)" >> $LOG ;;
    port)    { hdr $s; (cd $R/TraitDifferentialEquations && nice -n 10 $J -t 1 --startup-file=no --project=$H/env_demo_d -e 'using TraitWorld, TraitDifferentialEquations; include("test/runtests.jl")') 2>&1;
               echo "exit $?"; } > $LOG 2>&1; echo "testsets $(grep -c '^Test Summary' $LOG)" >> $LOG ;;
    tables)  { hdr $s; (cd $R/TraitTables && nice -n 10 $J -t 1 --startup-file=no --project=$H/env_tables_b -e 'using TraitWorld, TraitTables; println(pathof(TraitWorld)); include("test/runtests.jl")') 2>&1;
               echo "exit $?"; } > $LOG 2>&1; echo "testsets $(grep -c '^Test Summary' $LOG)" >> $LOG ;;
    makie)   { hdr $s; (cd $R/TraitMakie && nice -n 10 $J -t 1 --startup-file=no --project=$H/env_demo_d -e 'using TraitWorld, TraitMakie; println(pathof(TraitWorld)); include("test/runtests.jl")') 2>&1;
               echo "exit $?"; } > $LOG 2>&1; echo "testsets $(grep -c '^Test Summary' $LOG)" >> $LOG ;;
    builds)  bash $H/f-builds.sh $L $T > /dev/null 2>&1 ;;
    small)   bash $H/small.sh f-$L $T > /dev/null 2>&1 ;;
    apps)    bash $H/f-apps.sh $L $T > /dev/null 2>&1 ;;
    sessions) TREE=$T ENVD=$H/env_demo_d bash $H/sessions.sh f-$L 3 > /dev/null 2>&1 ;;
  esac
  echo "$s done $(date +%T) load $(cut -d' ' -f1-3 /proc/loadavg)"
done
