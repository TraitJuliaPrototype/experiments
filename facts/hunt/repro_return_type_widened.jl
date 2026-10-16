# FAIL 2: return_type is folded from the method instance jl_method_lookup_by_tt picks (compilation
# signature, widened for Function / Type / Vararg / @nospecialize arguments), not from inference at the call's signature
using TraitWorld
module M
ns(@nospecialize x) = x
passf(f) = f
pass(t) = t
vaa(xs...) = xs
end
k() = (Base.promote_op(M.ns, Int), Base.promote_op(M.passf, typeof(sin)), Base.promote_op(M.pass, Type{Int}),
       Base.promote_op(M.vaa, ntuple(_ -> Int, 10)...), typeof(M.ns.(Int[])))
println("plain:  ", k())                          # (Int64, typeof(sin), DataType, NTuple{10, Int64}, Vector{Int64})
println("policy: ", TraitWorld._facts_call(k))    # (Any, Function, Type, Tuple{Int64, Vararg{Int64}}, Vector{Any})
