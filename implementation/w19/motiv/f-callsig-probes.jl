# W-19, up/19: what a package's method for its own type invalidates of the system image's code, where
# the method is of a function the image calls at a wider instance than the call (`@nospecialize`, `!==`).
#   julia --startup-file=no f-callsig-probes.jl <probe>
# One probe per process; prints the distinct instances invalidated and the methods holding the most.
const PROBES = Dict(
    # `!==`: vanilla infers every call at `(Any, Any)`
    "ne"            => :(begin struct W19N end; Base.:(!==)(::W19N, ::W19N) = false end),
    # the callees with the most backedges by the call's signature in up/19's system image (f-callsig-census.jl)
    "typejoin"      => :(begin struct W19D end; Base.typejoin(::Type{W19D}, ::Type{W19D}) = W19D end),
    "promote_type"  => :(begin struct W19P end; Base.promote_type(::Type{W19P}, ::Type{W19P}) = W19P end),
    "preserve"      => :(begin struct W19H end; Base.preserve_handle(::W19H) = nothing end),
    "length"        => :(begin struct W19L <: AbstractVector{Int} end; Base.size(::W19L) = (1,); Base.length(::W19L) = 1 end),
)
probe = ARGS[1]
logs = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
Core.eval(Main, PROBES[probe])
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
insts = IdSet{Any}(); bymeth = Dict{Any,Int}()
for x in logs
    mi = x isa Core.CodeInstance ? x.def : x
    mi isa Core.MethodInstance || continue
    mi in insts && continue
    push!(insts, mi)
    m = mi.def
    k = m isa Method ? string(m.module, ".", m.name) : string(m)
    bymeth[k] = get(bymeth, k, 0) + 1
end
top = sort!(collect(bymeth); by = last, rev = true)
println(rpad(probe, 12), " invalidated instances ", lpad(length(insts), 6), "  | ", join(("$(k) $(v)" for (k, v) in first(top, 5)), ", "))
