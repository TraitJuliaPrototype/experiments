#!/bin/bash
# The ODE program trimmed (../../w135/apps/ode.jl), by ../../w166/build_c.sh with VERIFY=1 on julia-next, logs here,
# the images in this part's depot (DEPOT; the steps before cb-step4 wrote them to the shared depot, see the README);
# then the errors by module and root (../../w135/summarize.py) and by statement (probes/kinds.py).
#     bash build.sh <step>      -> logs/w166c-w158p-<step>.build.log, logs/w158p-<step>.kinds.txt; the binary deleted
#     APP=apps/ode_cb bash build.sh <step>      the program with callbacks the program knows (apps/ode_cb.jl)
set -u; ulimit -c 0; H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"
O=$(mktemp -d)
APP=${APP:-}; if [ -n "$APP" ]; then a=../../w158/port/$APP; export PKGS="TraitWorld TraitDifferentialEquations"; else a=ode; fi
DEPOT=$TW_ROOT/.julia-depot/agent-depots/w158p VERIFY=1 JULIA_TREE=julia-next NAME=w158p-$1 LOGDIR=$H/logs OUTDIR=$O bash $W166/build_c.sh $a
python3 $W135/summarize.py $H/logs/w166c-w158p-$1.build.log | tee $H/logs/w158p-$1.kinds.txt
python3 $H/probes/kinds.py $H/logs/w166c-w158p-$1.build.log | tee -a $H/logs/w158p-$1.kinds.txt
[ -x $O/w166c-w158p-$1 ] && { $O/w166c-w158p-$1 > $H/logs/w158p-$1.bin.out 2>&1; echo "binary: exit $?" | tee -a $H/logs/w158p-$1.kinds.txt; cat $H/logs/w158p-$1.bin.out; }
rm -rf "$O"
