#!/bin/bash
# E-260: the C7 placement count on the patched build, over U5's five environments.
# Run from anywhere after `source env.sh`; one job, 4 cores.
R=${TW_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
cd "$R"
export JULIA_PKG_OFFLINE=true OPENBLAS_NUM_THREADS=1 C7_OUT=$R/experiments/unification/c7count/out
mkdir -p "$C7_OUT"
J="experiments/tools/jl --name e260 julia-1.13/julia --startup-file=no"
C=experiments/unification/c7count/c7count.jl
U=experiments/w83/u5
run() { label=$1; env=$2; shift 2; echo "== $label"; $J --project=$env $C $label $U/$label-bounded.tsv "$@"; }
run tables experiments/w83/u5/env_tables TraitTables TraitCSV InlineStrings
run forks forks/env_forks Tables DataFrames CSV InlineStrings PooledArrays
run tde experiments/w83/u5/env_tde TraitDifferentialEquations ODECore TraitArrayTools TraitIndexing TraitRodas TraitNonlinearSolve TraitImplicit TraitLinSolvers TraitNLSolvers
run makie experiments/w83/u5/env_makie TraitMakie MakieCompat MakieCompatStats
run ndport ndport/env_r5 NetworkDynamics GraphMakie Graphs NetworkLayout Observables Static SymbolicIndexingInterface MakieCompat TraitMakie TraitDifferentialEquations ODECore TraitArrayTools TraitIndexing TraitNonlinearSolve TraitRodas
echo ALL-DONE
