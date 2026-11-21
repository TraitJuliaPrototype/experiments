#!/bin/bash
# W-158, fourth part: the ODE program trimmed (../../w135/apps/ode.jl; APP=apps/ode_cb the program with callbacks it
# knows, ../port/apps/ode_cb.jl) as ../port/build.sh builds it (../../w166/build_c.sh, VERIFY=1), with this part's
# Julia (JT, default wt/w158-julia), the depot agent-depots/w158 and the project ../env_demo_d (the library at
# wt/w158b-tw); the build's report of its rounds and members (JULIA_CLOSED_BUILD_REPORT=1). Then the errors by
# statement (../port/probes/kinds.py); where it builds, the binary is run and its output compared with a session's run
# of the same file with the build's project (logs/f-<label>.{bin,session}.out). The binary's size is in the build log.
#     bash f-probes/ode_build.sh <label>           -> logs/w166c-f-<label>.build.log, logs/f-<label>.kinds.txt
set -u; ulimit -c 0; H=$(cd "$(dirname "$0")/.." && pwd); source "$H/env.sh" > /dev/null
JT=${JT:-wt/w158-julia}; ENVD=$H/env_demo_d; O=$(mktemp -d)
APP=${APP:-}
if [ -n "$APP" ]; then a=../../w158/port/$APP; f=$H/port/$APP.jl; export PKGS="TraitWorld TraitDifferentialEquations"
else a=ode; f=$TW_ROOT/experiments/implementation/w135/apps/ode.jl; fi
JULIA_CLOSED_BUILD_REPORT=1 DEPOT=$TW_ROOT/.julia-depot/agent-depots/w158 VERIFY=1 JULIA_TREE=$JT TW=wt/w158b-tw \
  NAME=f-$1 LOGDIR=$H/logs OUTDIR=$O bash $W166/build_c.sh $a $ENVD
python3 $H/port/probes/kinds.py $H/logs/w166c-f-$1.build.log | tee $H/logs/f-$1.kinds.txt
if [ -x $O/w166c-f-$1 ]; then
  $O/w166c-f-$1 > $H/logs/f-$1.bin.out 2>&1; echo "binary: exit $?, $(stat -c %s $O/w166c-f-$1) bytes" | tee -a $H/logs/f-$1.kinds.txt
  $TW_ROOT/$JT/julia --project=$ENVD -e 'include(ARGS[1])' $f > $H/logs/f-$1.session.out 2>&1
  cmp -s $H/logs/f-$1.bin.out $H/logs/f-$1.session.out && r=equal || r=differ
  echo "output: binary and session $r" | tee -a $H/logs/f-$1.kinds.txt; cat $H/logs/f-$1.bin.out
fi
rm -rf "$O"
