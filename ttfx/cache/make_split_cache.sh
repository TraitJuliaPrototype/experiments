#!/bin/bash
# E-177: an emulated cache split by dependency set, for setting X (D, Dp, S): a perturbed session recorded with the
# solver library loaded first (cache/record_cis.jl with REC_SOLVER), then two packages: SessionCacheXS (the solver
# part; its dependencies the solver library) and SessionCacheXP (the plotting part; the solver and plotting
# libraries); an environment env_split_X with both.   bash cache/make_split_cache.sh X
set -uo pipefail
cd "$(dirname "$0")/.."; H=$PWD; R=$(cd ../.. && pwd); X=$1
JP=$R/julia-1.13/julia; JS=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia
export JULIA_PKG_GC_AUTO=false OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 JULIA_NUM_PRECOMPILE_TASKS=8
F=(--startup-file=no --compiled-modules=existing --pkgimages=existing)
case $X in
  D)  J=$JP; env=env_d; dep=""; pre=(env WL_D=trait); script=workload_d.jl; sol="TraitDifferentialEquations"; solu="TraitDifferentialEquations, TraitWorld"; plu="TraitDifferentialEquations, TraitMakie, TraitWorld" ;;
  Dp) J=$JP; env=env_d; dep=""; pre=(env WL_D=plain); script=workload_d.jl; sol="PlainODE"; solu="PlainODE"; plu="PlainODE, PlainPlots" ;;
  C)  J=$JP; env=env_core; dep="$H/depot-C:$HOME/.julia:"; pre=(env); script=workload.jl; sol="OrdinaryDiffEqTsit5,OrdinaryDiffEqRosenbrock"; solu="OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, TraitWorld"; plu="OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, CairoMakie, TraitWorld" ;;
  S)  J=$JS; env=env_up; dep="$H/depot-S:$HOME/.julia:"; pre=(env); script=workload.jl; sol="OrdinaryDiffEqTsit5,OrdinaryDiffEqRosenbrock"; solu="OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock"; plu="OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, CairoMakie" ;;
esac
[ -n "$dep" ] && export JULIA_DEPOT_PATH=$dep || unset JULIA_DEPOT_PATH
mkdir -p cache/split-$X logs/cache
WL_SHAPE=perturbed REC_SOLVER=$sol flock /tmp/claude-1000/julia-review.lock nice -n 19 "${pre[@]}" $J "${F[@]}" --project=$env cache/record_cis.jl $script out/png cache/split-$X/trace.jl > logs/cache/split-$X.out 2>&1
grep "^R " logs/cache/split-$X.out
mkpkg() {  # name, jls part, uses
  local name=$1 part=$2 uses=$3 P=cache/split-$X/$1
  mkdir -p $P/src; cp cache/split-$X/trace-$part.jls $P/src/trace.jls
  printf 'name = "%s"\nuuid = "%s"\nversion = "0.0.1"\n\n[deps]\n' $name $(python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_DNS, '$name'))") > $P/Project.toml
  for u in ${uses//,/ }; do grep -E "^$u = \"" $env/Project.toml >> $P/Project.toml; done
  echo 'Serialization = "9e88b42a-f829-5b0c-bbe9-9e923198166b"' >> $P/Project.toml
  cat > $P/src/$name.jl <<JL
# E-177: one part of an emulated cache split by dependency set: the types recorded in trace.jls, compiled here.
module $name
using $uses, Serialization
for (id, m) in Base.loaded_modules
    n = Symbol(id.name)
    isdefined(@__MODULE__, n) || Core.eval(@__MODULE__, :(const \$n = \$m))
end
function fpc(@nospecialize(T))
    w = Base.get_world_counter()
    ms = Base._methods_by_ftype(T, 1, w)
    (ms isa Vector && length(ms) == 1) || return false
    mi = Base.Compiler.specialize_method(ms[1])
    return Base.Compiler.typeinf_ext_toplevel(mi, w, Base.Compiler.SOURCE_MODE_ABI, Base.Compiler.TRIM_NO, Base.Compiler.FACTS_OWNER) !== nothing
end
checked(@nospecialize(T)) = (isdefined(@__MODULE__, :TraitWorld) && TraitWorld._check_ahead!(@__MODULE__, nothing, T); true)
include_dependency(joinpath(@__DIR__, "trace.jls"))
const COUNTS = let r = Serialization.deserialize(joinpath(@__DIR__, "trace.jls")), ok = 0, failed = 0
    for T in r.plain;  (try precompile(T) catch; false end) ? (ok += 1) : (failed += 1); end
    for T in r.facts;  (try fpc(T) catch; false end) ? (ok += 1) : (failed += 1); end
    for T in r.checks; (try checked(T) catch; false end) ? (ok += 1) : (failed += 1); end
    (ok = ok, failed = failed)
end
end
JL
}
mkpkg SessionCache${X}S solver "$solu"
mkpkg SessionCache${X}P plot "$plu"
rm -rf env_split_$X; cp -r $env env_split_$X
flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no --project=env_split_$X -e "using Pkg; Pkg.develop([PackageSpec(path=\"cache/split-$X/SessionCache${X}S\"), PackageSpec(path=\"cache/split-$X/SessionCache${X}P\")]); t = @elapsed Pkg.precompile(); println(\"precompile s=\", round(t; digits=1))" > logs/cache/split-$X-precompile.log 2>&1
grep -E "precompile s=|ERROR" logs/cache/split-$X-precompile.log | tail -2
flock /tmp/claude-1000/julia-review.lock nice -n 19 $J "${F[@]}" --project=env_split_$X -e "using SessionCache${X}S, SessionCache${X}P; println(\"$X split: solver \", SessionCache${X}S.COUNTS, \"; plotting \", SessionCache${X}P.COUNTS)"
