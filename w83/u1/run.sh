#!/bin/bash
# U1 (E-258): run the definition checks over the samples. Usage: run.sh <log name>
# The load path stacks the forks' environment (DataFrames, Tables, TraitWorld) and NetworkDynamics' plotting
# environment (TraitMakie, MakieCompat, Graphs on the ports); one Julia job through experiments/tools/jl.
set -eu
U1=$(cd "$(dirname "$0")" && pwd)
R=$(cd "$U1/../../.." && pwd)
LOG=${1:-run}
export JULIA_LOAD_PATH="$R/forks/env_forks:$R/ndport/env_r2plot:@stdlib"
export JULIA_PKG_OFFLINE=true JULIA_TW_DEFCHECK=0
{
  echo "# $(date -Is) julia-1.13 $(git -C "$R/julia-1.13" rev-parse --short HEAD), TraitWorld $(git -C "$R/TraitWorld" rev-parse --short HEAD), forks $(git -C "$R/forks" rev-parse --short HEAD), TraitMakie $(git -C "$R/TraitMakie" rev-parse --short HEAD), Graphs-p4 $(git -C "$R/ndport/pkgs/Graphs-p4" rev-parse --short HEAD), load $(cut -d' ' -f1 /proc/loadavg)"
  "$R/experiments/tools/jl" --name w83u1 "$R/julia-1.13/julia" --startup-file=no "$U1/run.jl"
} 2>&1 | tee "$U1/logs/$LOG.log"
