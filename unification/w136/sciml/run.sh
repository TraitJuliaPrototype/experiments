#!/bin/bash
# E-363: bash run.sh -- the three cases in three forms, one process each -> logs/run.log and the
# messages' texts in logs/. Upstream's packages are read from the home depot (they are not in the
# workspace's); its compiled images go to a depot inside the workspace.
set -u
H=$(cd "$(dirname "$0")" && pwd); cd "$H"; R=$(cd "$H/../../../.." && pwd); source "$R/env.sh"
rev() { git -C "$R/$1" log -1 --format=%h; }
D=$R/experiments/unification/w134/env_demo
{
echo "# E-363 $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified $(rev julia-unified) julia-vanilla $(rev julia-vanilla) TraitWorld-unified $(rev TraitWorld-unified) TraitDifferentialEquations-unified $(rev TraitDifferentialEquations-unified)"
JULIA_DEPOT_PATH="$R/.julia-depot/agent-depots/e363:$R/.julia-depot:$HOME/.julia:" JULIA_PKG_OFFLINE=true nice -n 10 "$R/julia-vanilla/julia" -t 1 --startup-file=no --color=no --project="$H/env_upstream" upstream.jl 2>&1 | grep -v "^\s*$"
JULIA_PKG_OFFLINE=true nice -n 10 "$R/julia-unified/julia" -t 1 --startup-file=no --color=no --project="$D" port.jl trait 2>&1
JULIA_PKG_OFFLINE=true nice -n 10 "$R/julia-vanilla/julia" -t 1 --startup-file=no --color=no --project="$D" port.jl plain 2>&1
} | tee logs/run.log
