#!/bin/bash
# E-255 (U7): the runs, through experiments/tools/jl (slots). Usage: runall.sh A|B|all
#   A: TraitWorld's suite, TraitWorld's images re-inferred, TraitTables' and TraitCSV's tests
#   B: TraitDifferentialEquations' and TraitMakie's tests and images, TraitTables'/TraitCSV's images
#   all: TraitWorld's suite in the test bed `all` (the facts system image)
set -u
U7=$(cd "$(dirname "$0")" && pwd); R=$(cd "$U7/../../.." && pwd); cd "$R"
J=$R/julia-1.13/julia; JL="$R/experiments/tools/jl --name w83u7"; P=$U7/prelude.jl
export JULIA_PKG_OFFLINE=true
run() {  # tag project script [env...]
  local tag=$1 proj=$2 script=$3; shift 3
  env "$@" JULIA_LOAD_PATH="$U7/env:@:@v#.#:@stdlib" $JL $J --threads=1 --project=$proj $U7/run.jl $tag $script > $U7/logs/$tag.log 2>&1
  echo "$tag rc=$?"
}
pkgtest() {  # tag project
  U7_TAG=$1 $JL $J --project=$2 -e "using Pkg; Pkg.test(; julia_args = \`--threads=1 -L $P\`)" > $U7/logs/$1.log 2>&1
  echo "$1 rc=$?"
}
case $1 in
A)
  run traitworld-product TraitWorld TraitWorld/test/runtests.jl
  run traitworld-reinfer TraitWorld $U7/reinfer.jl U7_PKGS=TraitWorld
  pkgtest TraitTables TraitTables
  pkgtest TraitCSV TraitCSV ;;
B)
  pkgtest TraitDifferentialEquations TraitDifferentialEquations
  run TraitDifferentialEquations-reinfer TraitDifferentialEquations $U7/reinfer.jl U7_PKGS=TraitDifferentialEquations,TraitArrayTools,TraitIndexing,TraitRodas,TraitNonlinearSolve,ODECore
  pkgtest TraitMakie TraitMakie
  run TraitMakie-reinfer TraitMakie $U7/reinfer.jl U7_PKGS=TraitMakie
  run TraitTables-reinfer TraitTables $U7/reinfer.jl U7_PKGS=TraitTables
  run TraitCSV-reinfer TraitCSV $U7/reinfer.jl U7_PKGS=TraitCSV ;;
all)
  env JULIA_LOAD_PATH="$U7/env:@:@v#.#:@stdlib" $JL $J -J $R/julia-1.13/usr/lib/julia/facts/sys.so --threads=1 --project=TraitWorld $U7/run.jl traitworld-all TraitWorld/test/runtests.jl > $U7/logs/traitworld-all.log 2>&1
  echo "traitworld-all rc=$?" ;;
esac
