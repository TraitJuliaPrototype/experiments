#!/bin/bash
# E-172: emulate a cache across sessions for setting X (D, Dp or S): trace a perturbed session, keep the
# compiled statements that do not name Main, and make a package SessionCacheX whose precompile step runs
# them; an environment env_cache_X with it; precompiled into X's depot.   bash cache/make_cache.sh X
set -uo pipefail
cd "$(dirname "$0")/.."; H=$PWD; R=$(cd ../.. && pwd); X=$1
JP=$R/julia-1.13/julia; JS=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia
export JULIA_PKG_GC_AUTO=false OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 JULIA_NUM_PRECOMPILE_TASKS=2
F=(--startup-file=no --compiled-modules=existing --pkgimages=existing)
case $X in
  D)  J=$JP; env=env_d; dep=""; pre=(env WL_D=trait); script=workload_d.jl; uses="TraitDifferentialEquations, TraitMakie, TraitWorld" ;;
  Dp) J=$JP; env=env_d; dep=""; pre=(env WL_D=plain); script=workload_d.jl; uses="PlainODE, PlainPlots" ;;
  S)  J=$JS; env=env_up; dep="$H/depot-S:$HOME/.julia:"; pre=(env); script=workload.jl; uses="OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, CairoMakie" ;;
esac
[ -n "$dep" ] && export JULIA_DEPOT_PATH=$dep || unset JULIA_DEPOT_PATH
P=cache/SessionCache$X; mkdir -p $P/src logs/cache
WL_SHAPE=perturbed flock /tmp/claude-1000/julia-review.lock nice -n 19 "${pre[@]}" $J "${F[@]}" --project=$env --trace-compile=$P/src/trace.jl $script out/png > logs/cache/$X-trace.out 2>&1
echo "$X traced: $(grep -c '^precompile' $P/src/trace.jl) statements, $(grep -c 'Main\.' $P/src/trace.jl) naming Main"
uuid=$(python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_DNS, 'SessionCache$X'))")
cat > $P/Project.toml <<TOML
name = "SessionCache$X"
uuid = "$uuid"
version = "0.0.1"

[deps]
TOML
for u in ${uses//,/ }; do grep -E "^$u = \"" $env/Project.toml >> $P/Project.toml; done
cat > $P/src/SessionCache$X.jl <<JL
# E-172: an emulated cache across sessions: the statements a perturbed session compiled (trace.jl), those that
# do not name Main, compiled into this package's image.
module SessionCache$X
using $uses
for (id, m) in Base.loaded_modules
    n = Symbol(id.name)
    isdefined(@__MODULE__, n) || Core.eval(@__MODULE__, :(const \$n = \$m))
end
const COUNTS = let ok = 0, failed = 0, skipped = 0
    for line in eachline(joinpath(@__DIR__, "trace.jl"))
        startswith(line, "precompile") || continue
        if occursin("Main.", line); skipped += 1; continue; end
        r = try Core.eval(@__MODULE__, Meta.parse(line)) catch; false end
        r === true ? (ok += 1) : (failed += 1)
    end
    (ok = ok, failed = failed, skipped = skipped)
end
end
JL
rm -rf env_cache_$X; cp -r $env env_cache_$X
flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no --project=env_cache_$X -e "using Pkg; Pkg.develop(path=\"$P\"); t = @elapsed Pkg.precompile(); println(\"precompile s=\", round(t; digits=1))" > logs/cache/$X-precompile.log 2>&1
grep -E "precompile s=|ERROR" logs/cache/$X-precompile.log | tail -2
flock /tmp/claude-1000/julia-review.lock nice -n 19 $J "${F[@]}" --project=env_cache_$X -e "using SessionCache$X; println(\"$X cache: \", SessionCache$X.COUNTS)"
