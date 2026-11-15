#!/usr/bin/env bash
# E-404's environments: W-134's env_lib (CSV, DataFrames, the nine loads' packages, TraitWorld) with TraitDifferentialEquations
# and its packages added by path; env_head at the heads, env_base at the tag (TraitWorld-base, wt/w151-base/TDE).
set -euo pipefail
H=$(cd "$(dirname "$0")" && pwd); source $H/../env.sh >/dev/null
for which in head base; do
  d=$H/env_$which; mkdir -p $d
  cp $TW_ROOT/experiments/unification/w134/env_lib/Project.toml $TW_ROOT/experiments/unification/w134/env_lib/Manifest.toml $d/
  if [ $which = head ]; then TW=$TW_ROOT/TraitWorld-unified; TDE=$TW_ROOT/TraitDifferentialEquations-unified
  else TW=$TW_ROOT/TraitWorld-base; TDE=$TW_ROOT/wt/w151-base/TDE; fi
  sed -i "s#path = \"../../../../TraitWorld-unified\"#path = \"$TW\"#" $d/Project.toml $d/Manifest.toml
  $JU --startup-file=no --project=$d -e "using Pkg; Pkg.develop([PackageSpec(path = \"$TW\"), PackageSpec(path = \"$TDE/lib/ODECore\"), PackageSpec(path = \"$TDE/lib/TraitIndexing\"), PackageSpec(path = \"$TDE/lib/TraitArrayTools\"), PackageSpec(path = \"$TDE/lib/TraitRodas\"), PackageSpec(path = \"$TDE/lib/TraitNonlinearSolve\"), PackageSpec(path = \"$TDE\")])"
done
