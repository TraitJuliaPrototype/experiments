# E-167 (1): do reinterpret's padding helpers fold under the facts rule (W-57 part 1)?
#     JULIA_LOAD_PATH="../../TraitDifferentialEquations/scripts/env:@stdlib" julia --startup-file=no effects.jl
using ForwardDiff
const Compiler = Base.Compiler
const D1 = ForwardDiff.Dual{ForwardDiff.Tag{typeof(sin), Float64}, Float64, 1}
const D4 = ForwardDiff.Dual{Nothing, Float64, 4}
interp = Compiler.NativeInterpreter(; facts = true)
show_eff(label, f, tt) = (e = Base.infer_effects(f, tt; interp);
    println(rpad(label, 46), " foldable ", Compiler.is_foldable(e), "  nortsite ", Compiler.is_nortsite(e), "  ", e))
for (S, T) in ((D1, Float64), (D4, Float64), (Float64, D1), (Tuple{Float64, Int32}, Float64))
    show_eff("array_subpadding($S, $T)", Base.array_subpadding, (Type{S}, Type{T}))
end
show_eff("padding(D1)", Base.padding, (Type{D1},))
show_eff("packedsize(D1)", Base.packedsize, (Type{D1},))
show_eff("fieldcount(DataType)", Base.fieldcount, (DataType,))
show_eff("datatype_fieldcount(DataType)", Base.datatype_fieldcount, (DataType,))
show_eff("unwrap_unionall(Any)", Base.unwrap_unionall, (Any,))
show_eff("isabstracttype(Any)", Base.isabstracttype, (Any,))
show_eff("datatype_alignment(DataType)", Base.datatype_alignment, (DataType,))
# the call reinterpret makes: does it fold in a caller compiled by facts?
g(x::Vector{D1}) = reinterpret(Float64, x)
Compiler.WITHDRAWN_LOG[] = true
ci = only(Base.code_typed(g, (Vector{D1},); interp = Compiler.NativeInterpreter(; facts = true)))   # an interpreter in g's world
Compiler.WITHDRAWN_LOG[] = false
n = count(st -> Meta.isexpr(st, :call) || Meta.isexpr(st, :invoke), ci.first.code)
println("reinterpret(Float64, ::Vector{D1}) under facts: ", length(ci.first.code), " statements, ", n, " calls")
