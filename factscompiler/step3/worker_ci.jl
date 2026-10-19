# The worker's CodeInstances after a typed call: owner, whether inferred source is kept, the inlining cost.
include(joinpath(@__DIR__, "untyped_defs.jl"))
typed_t(SA("a", [1.0]), 3)
for m in methods(UT.rmean), mi in Base.specializations(m)
    mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
    ci = mi.cache
    while true
        src = ci.inferred
        cost = src isa String || src isa Vector{UInt8} ? ccall(:jl_ir_inlining_cost, UInt16, (Any,), src) :
               src isa Core.CodeInfo ? src.inlining_cost : nothing
        println(mi.specTypes, "\n   owner=", repr(ci.owner), " inferred=", typeof(src), " inlining_cost=", cost, " invoke=", ci.invoke != C_NULL)
        isdefined(ci, :next) || break; ci = ci.next
    end
end
ct = code_typed(typed_t, (SA, Int))[1].first
for st in ct.code
    st isa Expr && st.head === :invoke && println("invoke target: ", st.args[1], " owner=", repr(st.args[1] isa Core.CodeInstance ? st.args[1].owner : :mi))
end
