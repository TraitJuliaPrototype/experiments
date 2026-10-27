#!/bin/bash
# E-186: validation remembered for an unchanged environment (W-64). After a build of the patched Julia: precompile
# U's and C's environments, clear the remembered outcomes, then U and C without and with JULIA_REMEMBER_VALIDATION=1
# (the warm-up records, the measured sessions reuse), a chain test (a different definition before `using`: no reuse),
# and the digests compared.   bash loader/e186.sh
set -uo pipefail
cd "$(dirname "$0")/.."; H=$PWD; R=$(cd ../.. && pwd); J=$R/julia-1.13/julia
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=8 OPENBLAS_NUM_THREADS=1
mkdir -p logs/e186
for e in "env_up:" "env_core:$H/depot-C:$HOME/.julia:"; do
  env=${e%%:*}; dep=${e#*:}
  ( [ -n "$dep" ] && export JULIA_DEPOT_PATH=$dep
    flock /tmp/claude-1000/julia-review.lock nice -n 10 $J --startup-file=no --project=$env -e 'using Pkg; t = @elapsed Pkg.precompile(); println("precompile s=", round(t; digits=1))' ) > logs/e186/precompile-$env.log 2>&1
  grep -E "precompile s=|ERROR" logs/e186/precompile-$env.log | tail -2
done
rm -rf $HOME/.julia/compiled/v1.13/validation $H/depot-C/compiled/v1.13/validation
bash run.sh e186 "U U/v C C/v" 3
nfiles() { ls $HOME/.julia/compiled/v1.13/validation 2>/dev/null | wc -l; }
chain() {  # a session that defines $1 before loading the solver, with remembering on
  JULIA_REMEMBER_VALIDATION=1 flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no --compiled-modules=existing --pkgimages=existing --project=env_up -e "$1; t = @elapsed using OrdinaryDiffEqTsit5; println(\"load \", round(t; digits=3))" 2>&1 | tail -1
}
echo "chain: files before $(nfiles)"
echo "chain: f() = 1, first: $(chain 'f() = 1'), files $(nfiles)"
echo "chain: f() = 1, again: $(chain 'f() = 1'), files $(nfiles)"
echo "chain: g(x::Int) = 2, first: $(chain 'g(x::Int) = 2'), files $(nfiles)"
for s in U U-v C C-v; do for i in 1 2 3; do echo "$s-$i $(grep -h '^D ' logs/e186/$s-$i.log | md5sum | cut -c1-12)"; done; done
