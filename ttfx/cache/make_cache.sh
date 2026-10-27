#!/bin/bash
# E-172: emulate a cache across sessions for setting X (D, Dp or S): trace a perturbed session, keep the
# compiled statements that do not name Main, and make a package SessionCacheX whose precompile step runs
# them; an environment env_cache_X with it; precompiled into X's depot.   bash cache/make_cache.sh X [n]
# With n (S, U, C): the session traced with the function behind NoSpecialize (E-174); the cache is SessionCacheXn.
# CI=1 (E-175): record every CodeInstance the session created (cache/record_cis.jl), not only compile roots;
# the cache is SessionCacheX[n]ci.
set -uo pipefail
cd "$(dirname "$0")/.."; H=$PWD; R=$(cd ../.. && pwd); X=$1; V=${2:-}
[ "${CI:-0}" = 1 ] && V=${V}ci
# E-184: CACHE_TAG names a cache recorded under other WL_* settings (WL_PARAMS, WL_SAVEAT, WL_NORM, passed through)
V=${V}${CACHE_TAG:-}
[[ "$V" == n* ]] && export WL_SPEC=nospec || unset WL_SPEC
JP=$R/julia-1.13/julia; JS=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia
export JULIA_PKG_GC_AUTO=false OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 JULIA_NUM_PRECOMPILE_TASKS=2
F=(--startup-file=no --compiled-modules=existing --pkgimages=existing)
case $X in
  D)  J=$JP; env=env_d; dep=""; pre=(env WL_D=trait); script=workload_d.jl; uses="TraitDifferentialEquations, TraitMakie, TraitWorld" ;;
  Dp) J=$JP; env=env_d; dep=""; pre=(env WL_D=plain); script=workload_d.jl; uses="PlainODE, PlainPlots" ;;
  S)  J=$JS; env=env_up; dep="$H/depot-S:$HOME/.julia:"; pre=(env); script=workload.jl; uses="OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, CairoMakie" ;;
  C)  J=$JP; env=env_core; dep="$H/depot-C:$HOME/.julia:"; pre=(env); script=workload.jl; uses="OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, CairoMakie, TraitWorld" ;;
esac
[ -n "$dep" ] && export JULIA_DEPOT_PATH=$dep || unset JULIA_DEPOT_PATH
P=cache/SessionCache$X$V; mkdir -p $P/src logs/cache
if [ "${CI:-0}" = 1 ]; then   # E-175: every CodeInstance the session created, not only compile roots
  WL_SHAPE=perturbed flock /tmp/claude-1000/julia-review.lock nice -n 19 "${pre[@]}" $J "${F[@]}" --project=$env cache/record_cis.jl $script out/png $P/src/trace.jl > logs/cache/$X$V-ci.out 2>&1
  grep "^R " logs/cache/$X$V-ci.out
else
  WL_SHAPE=perturbed flock /tmp/claude-1000/julia-review.lock nice -n 19 "${pre[@]}" $J "${F[@]}" --project=$env --trace-compile=$P/src/trace.jl $script out/png > logs/cache/$X-trace.out 2>&1
fi
echo "$X traced: $(grep -c '^precompile' $P/src/trace.jl) statements, $(grep -c 'Main\.' $P/src/trace.jl) naming Main"
uuid=$(python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_DNS, 'SessionCache$X$V'))")
cat > $P/Project.toml <<TOML
name = "SessionCache$X$V"
uuid = "$uuid"
version = "0.0.1"

[deps]
TOML
for u in ${uses//,/ }; do grep -E "^$u = \"" $env/Project.toml >> $P/Project.toml; done
echo 'Serialization = "9e88b42a-f829-5b0c-bbe9-9e923198166b"' >> $P/Project.toml
cat > $P/src/SessionCache$X$V.jl <<JL
# E-172: an emulated cache across sessions: the statements a perturbed session compiled (trace.jl), those that
# do not name Main, compiled into this package's image.
module SessionCache$X$V
using $uses, Serialization
for (id, m) in Base.loaded_modules
    n = Symbol(id.name)
    isdefined(@__MODULE__, n) || Core.eval(@__MODULE__, :(const \$n = \$m))
end
"Compile the method instance of signature \`T\` for the facts owner (a statement recorded from facts code, E-175)."
function fpc(@nospecialize(T))
    w = Base.get_world_counter()
    ms = Base._methods_by_ftype(T, 1, w)
    (ms isa Vector && length(ms) == 1) || return false
    mi = Base.Compiler.specialize_method(ms[1])
    ci = Base.Compiler.typeinf_ext_toplevel(mi, w, Base.Compiler.SOURCE_MODE_ABI, Base.Compiler.TRIM_NO, Base.Compiler.FACTS_OWNER)
    return ci !== nothing
end
"Run a worker signature's first-call check now and keep its result in this package's image (TraitWorld's ahead checks)."
checked(@nospecialize(T)) = (isdefined(@__MODULE__, :TraitWorld) && TraitWorld._check_ahead!(@__MODULE__, nothing, T); true)
include_dependency(joinpath(@__DIR__, "trace.jl"))   # the statements are this package's source too
isfile(joinpath(@__DIR__, "trace.jls")) && include_dependency(joinpath(@__DIR__, "trace.jls"))
const COUNTS = isfile(joinpath(@__DIR__, "trace.jls")) ? let r = Serialization.deserialize(joinpath(@__DIR__, "trace.jls")), ok = 0, failed = 0
    for T in r.plain;  (try precompile(T) catch; false end) ? (ok += 1) : (failed += 1); end
    for T in r.facts;  (try fpc(T) catch; false end) ? (ok += 1) : (failed += 1); end
    for T in r.checks; (try checked(T) catch; false end) ? (ok += 1) : (failed += 1); end
    (ok = ok, failed = failed, skipped = 0, source = :jls)
end : let ok = 0, failed = 0, skipped = 0
    for line in eachline(joinpath(@__DIR__, "trace.jl"))
        (startswith(line, "precompile") || startswith(line, "fpc") || startswith(line, "checked")) || continue
        if occursin("Main.", line); skipped += 1; continue; end
        r = try Core.eval(@__MODULE__, Meta.parse(line)) catch; false end
        r === true ? (ok += 1) : (failed += 1)
    end
    (ok = ok, failed = failed, skipped = skipped)
end
end
JL
rm -rf env_cache_$X$V; cp -r $env env_cache_$X$V
flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no --project=env_cache_$X$V -e "using Pkg; Pkg.develop(path=\"$P\"); t = @elapsed Pkg.precompile(); println(\"precompile s=\", round(t; digits=1))" > logs/cache/$X-precompile.log 2>&1
grep -E "precompile s=|ERROR" logs/cache/$X-precompile.log | tail -2
flock /tmp/claude-1000/julia-review.lock nice -n 19 $J "${F[@]}" --project=env_cache_$X$V -e "using SessionCache$X$V; println(\"$X$V cache: \", SessionCache$X$V.COUNTS)"
