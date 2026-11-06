#!/bin/bash
# E-263, E-264: run the census in one session. Usage: run.sh <session>  (forks | nd | tables)
# One Julia job through experiments/tools/jl; no timing is measured.
set -eu
C=$(cd "$(dirname "$0")" && pwd)
R=$(cd "$C/../../.." && pwd)
S=$1
case $S in
  forks)  export JULIA_LOAD_PATH="$R/forks/env_forks:$R/ndport/env_r2plot:@stdlib"
          export CENSUS_PKGS="Tables,DataFrames,CSV,TraitMakie,MakieCompat,Graphs,GraphMakie"
          export CENSUS_SCOPE="Tables,DataFrames,CSV,TraitMakie,MakieCompat,Graphs,GraphMakie,BaseTraits" ;;
  nd)     export JULIA_LOAD_PATH="$R/ndport/env_ports:@stdlib"
          export CENSUS_PKGS="NetworkDynamics,TraitDifferentialEquations,ODECore,TraitArrayTools,TraitIndexing,TraitNonlinearSolve,TraitRodas"
          export CENSUS_SCOPE="$CENSUS_PKGS" ;;
  tables) export JULIA_LOAD_PATH="$R/TraitReport/env_loads:@stdlib"
          export CENSUS_PKGS="TraitTables,TraitCSV,TraitReport"
          export CENSUS_SCOPE="$CENSUS_PKGS" ;;
  *) echo "unknown session $S"; exit 2 ;;
esac
export JULIA_PKG_OFFLINE=true JULIA_TW_DEFCHECK=0
mkdir -p "$C/logs"
{
  echo "# $(date -Is) julia-1.13 $(git -C "$R/julia-1.13" rev-parse --short HEAD), TraitWorld $(git -C "$R/TraitWorld" rev-parse --short HEAD), forks $(git -C "$R/forks" rev-parse --short HEAD), TraitMakie $(git -C "$R/TraitMakie" rev-parse --short HEAD), TDE $(git -C "$R/TraitDifferentialEquations" rev-parse --short HEAD), ndport $(git -C "$R/ndport" rev-parse --short HEAD), load $(cut -d' ' -f1 /proc/loadavg)"
  "$R/experiments/tools/jl" --name w105c "$R/julia-1.13/julia" --startup-file=no "$C/census.jl" "$S"
} 2>&1 | tee "$C/logs/$S.log"
