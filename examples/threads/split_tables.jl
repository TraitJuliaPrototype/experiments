# Split tables and the untyped callers' table under threads (W-9): several threads meet the same
# types for the first time at the same call sites, so their misses race to add entries
# (copy-on-write, published by compare-and-swap, compiler §4.3; untyped.jl). Expected: every result
# right, and afterwards each table holds every type once.
#     julia -t 4 --project=env threads/split_tables.jl
include(joinpath(@__DIR__, "..", "common.jl"))
using TraitWorld
Threads.nthreads() >= 2 || error("run with -t 4")
const NT = 24
let io = IOBuffer(), imp = IOBuffer()
    for i in 1:NT
        println(io, "struct Q$i; a::Float64; end")
        println(imp, "TraitWorld.@implement QM.QS Q$i begin qarea(s) = $(Float64(i)) * s.a end")
    end
    include_string(Main, String(take!(io)), "threads_types.jl")
    global IMPLS = String(take!(imp))
end
@trait_module module QM
using TraitWorld
export QS, qarea, qtotal, qtwice
@trait QS begin
    qarea(s::QS)::Float64
end
qtotal(v::Vector{Dynamic{QS}}) = (s = 0.0; for d in v; s += qarea(d); end; s)
qtwice(s::QS) = 2 * qarea(s)
end
include_string(Main, IMPLS, "threads_impls.jl")
const TYPES = [getglobal(Main, Symbol(:Q, i)) for i in 1:NT]
ucall(v::Vector{Any}) = (s = 0.0; for x in v; s += QM.qtwice(compiled_for(x))::Float64; end; s)
# every thread, in its own order, the types beyond the split and the untyped callers' table
results = Vector{Tuple{Float64,Float64}}(undef, 4 * Threads.nthreads())
Threads.@threads for k in eachindex(results)
    order = circshift(1:NT, k)
    vd = Dynamic{QM.QS}[Dynamic{QM.QS}(TYPES[i](1.0)) for i in order]
    va = Any[TYPES[i](1.0) for i in order]
    results[k] = (QM.qtotal(vd), ucall(va))
end
want = sum(Float64.(1:NT))
check("every thread's sum is right, through the split's table and the untyped callers' table", all(r -> r == (want, 2want), results))
tabs = something((@atomic Base.Compiler.SPLIT_TABLES.table), IdDict())
mine = [t for (k, t) in tabs if k[1] <: TraitWorld._DynOp && k[1].parameters[1] === QM.QS]
keysof(t) = collect((@atomic t.state).keys)
check("the split's tables hold each type beyond the split once, every one of them",
      !isempty(mine) && all(t -> allunique(keysof(t)), mine) && Set(reduce(vcat, keysof.(mine))) == Set(TYPES[5:end]))
summary()
