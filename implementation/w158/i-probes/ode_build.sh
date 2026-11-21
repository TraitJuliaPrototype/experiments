#!/bin/bash
# W-158, fifth part: ../f-probes/ode_build.sh with its logs named i-: the ODE program trimmed (APP=apps/ode_cb the
# program with callbacks it knows, ../port/apps/ode_cb.jl), VERIFY=1, with this part's Julia (JT, default
# wt/w158-julia), the depot agent-depots/w158 and the project ../env_demo_d (the library at wt/w158b-tw); the build's
# report (JULIA_CLOSED_BUILD_REPORT=1); the errors by statement; where it builds, the binary run and its output
# compared with a session's.
#     [APP=apps/ode_cb] bash i-probes/ode_build.sh <label>  -> logs/w166c-i-<label>.build.log, logs/i-<label>.kinds.txt
set -u; ulimit -c 0; H=$(cd "$(dirname "$0")/.." && pwd); source "$H/env.sh" > /dev/null
JT=${JT:-wt/w158-julia}; ENVD=$H/env_demo_d; O=$(mktemp -d)
APP=${APP:-}
if [ -n "$APP" ]; then a=../../w158/port/$APP; f=$H/port/$APP.jl; export PKGS="TraitWorld TraitDifferentialEquations"
else a=ode; f=$TW_ROOT/experiments/implementation/w135/apps/ode.jl; export PKGS="TraitWorld TraitDifferentialEquations"; fi
JULIA_CLOSED_BUILD_REPORT=1 DEPOT=$TW_ROOT/.julia-depot/agent-depots/w158 VERIFY=1 JULIA_TREE=$JT TW=wt/w158b-tw \
  NAME=i-$1 LOGDIR=$H/logs OUTDIR=$O bash $W166/build_c.sh $a $ENVD
python3 $H/port/probes/kinds.py $H/logs/w166c-i-$1.build.log | tee $H/logs/i-$1.kinds.txt
if [ -x $O/w166c-i-$1 ]; then
  $O/w166c-i-$1 > $H/logs/i-$1.bin.out 2>&1; echo "binary: exit $?, $(stat -c %s $O/w166c-i-$1) bytes" | tee -a $H/logs/i-$1.kinds.txt
  $TW_ROOT/$JT/julia --project=$ENVD -e 'include(ARGS[1])' $f > $H/logs/i-$1.session.out 2>&1
  cmp -s $H/logs/i-$1.bin.out $H/logs/i-$1.session.out && r=equal || r=differ
  echo "output: binary and session $r" | tee -a $H/logs/i-$1.kinds.txt; cat $H/logs/i-$1.bin.out
fi
rm -rf "$O"
