#!/bin/bash
# W-158, seventh part (compiler C-158, C-156; a copy of m-checks.sh, logs named p-; steps ode, odecb, nd, count added): the checks of a Julia tree with the library at wt/w158b-tw, one after another, one Julia
# job at a time, niced; no core files. Logs logs/p-<what>-<label>.log.
#     bash m-checks.sh <label> [tree] [step ...]      steps: gates base library port tables makie builds small apps sessions
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh" > /dev/null; R=$TW_ROOT
L=$1; T=${2:-wt/w158-julia}; shift 2 2>/dev/null; STEPS=${@:-gates base library port tables makie builds small apps ode odecb nd sessions count}
J=$R/$T/julia; P=$R/wt/w158b-tw; rev() { git -C "$R/$1" log -1 --format=%h; }
hdr() { echo "# W-158 p-$1 $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $T $(rev $T) library wt/w158b-tw $(rev wt/w158b-tw) TDE $(rev TraitDifferentialEquations)"; }
for s in $STEPS; do
  LOG=$H/logs/p-$s-$L.log
  case $s in
    gates)   { hdr $s; LIB=wt/w158b-tw bash $R/experiments/implementation/gates/run_all.sh $T 2>&1 | grep -E '^(FAIL|gates:|stage gates:)|^ ' ; } > $LOG 2>&1 ;;
    base)    { hdr $s; for t in core subtype Compiler/inline Compiler/inference Compiler/effects; do
                 (cd $R/$T/test && nice -n 10 $J --startup-file=no -e 'Base.runtests([ARGS[1]]; ncores = 1)' $t > /tmp/claude-harvest/p-base.out 2>&1)
                 echo "$t: exit $? $(grep -E 'SUCCESS|FAILURE' /tmp/claude-harvest/p-base.out | tail -1)"; done; } > $LOG 2>&1 ;;
    library) { hdr $s; (cd $P && nice -n 10 $J -t 1 --startup-file=no --project=. -e 'using TraitWorld; include("test/runtests.jl")') 2>&1;
               echo "exit $?"; } > $LOG 2>&1; echo "testsets $(grep -c '^Test Summary' $LOG)" >> $LOG ;;
    port)    { hdr $s; (cd $R/TraitDifferentialEquations && nice -n 10 $J -t 1 --startup-file=no --project=$H/env_demo_d -e 'using TraitWorld, TraitDifferentialEquations; include("test/runtests.jl")') 2>&1;
               echo "exit $?"; } > $LOG 2>&1; echo "testsets $(grep -c '^Test Summary' $LOG)" >> $LOG ;;
    tables)  { hdr $s; (cd $R/TraitTables && nice -n 10 $J -t 1 --startup-file=no --project=$H/env_tables_b -e 'using TraitWorld, TraitTables; println(pathof(TraitWorld)); include("test/runtests.jl")') 2>&1;
               echo "exit $?"; } > $LOG 2>&1; echo "testsets $(grep -c '^Test Summary' $LOG)" >> $LOG ;;
    makie)   { hdr $s; (cd $R/TraitMakie && nice -n 10 $J -t 1 --startup-file=no --project=$H/env_demo_d -e 'using TraitWorld, TraitMakie; println(pathof(TraitWorld)); include("test/runtests.jl")') 2>&1;
               echo "exit $?"; } > $LOG 2>&1; echo "testsets $(grep -c '^Test Summary' $LOG)" >> $LOG ;;
    builds)  bash $H/i-builds.sh p-$L $T > /dev/null 2>&1 ;;
    small)   bash $H/small.sh p-$L $T > /dev/null 2>&1 ;;
    apps)    bash $H/i-apps.sh p-$L $T m-trusted i-ctor3 i-gap3 i-mixed3 i-wrap3 i-param3 f-free f-bare f-union f-result f-gap f-gapfn e-boxcall e-ctor2 e-twochoice choice flow > /dev/null 2>&1 ;;
    ode)     JT=$T bash $H/i-probes/ode_build.sh p-ode-$L > $LOG 2>&1 ;;
    odecb)   JT=$T APP=apps/ode_cb bash $H/i-probes/ode_build.sh p-odecb-$L > $LOG 2>&1 ;;
    nd)      { hdr $s; (cd $R/ndport && nice -n 10 $J -t 2 --startup-file=no --project=$R/experiments/implementation/w161/nd/env_test_head scripts/r3_nd_tests.jl) 2>&1;
               echo "exit $?"; } > $LOG 2>&1 ;;
    count)   { hdr $s; D=$(mktemp -d); CSV=$R/experiments/interfaces/App/data/sample.csv
               awk 'BEGIN { print "id,x,y,name"; for (i = 1; i <= 500; i++) printf "%d,%.3f,%.3f,n%d\n", i, i*0.1, 100-i*0.05, i%7 }' > $D/t.csv
               for a in "report $CSV $D/r.png" "table $D/t.csv"; do set -- $a; echo "== $1"
                 nice -n 10 $J -t 1 --startup-file=no --project=$H/env_demo_d $H/m-probes/count.jl $R/experiments/implementation/w135/apps/$1.jl ${@:2} 2>&1 | grep '^count'; done
               echo "== odecb"; nice -n 10 $J -t 1 --startup-file=no --project=$H/env_demo_d $H/m-probes/count.jl $H/port/apps/ode_cb.jl 2>&1 | grep '^count'
               rm -rf $D; } > $LOG 2>&1 ;;
    sessions) TREE=$T ENVD=$H/env_demo_d bash $H/sessions.sh p-$L 3 > /dev/null 2>&1 ;;
  esac
  echo "$s done $(date +%T) load $(cut -d' ' -f1-3 /proc/loadavg)"
done
