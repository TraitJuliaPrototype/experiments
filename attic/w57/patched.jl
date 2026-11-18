# E-167: the effects check with the patched sources of isvatuple, fieldcount and datatype_fieldcount
# evaluated into Base first (a check before the rebuild; not a measurement).
J13 = joinpath(@__DIR__, "../../julia-1.13/base")
function defs(file, names)
    ex = Meta.parseall(read(joinpath(J13, file), String); filename = file)
    for x in ex.args
        x isa Expr || continue
        y = Meta.isexpr(x, :macrocall) ? x.args[end] : x
        Meta.isexpr(y, :function) || continue
        sig = y.args[1]; sig = Meta.isexpr(sig, :where) ? sig.args[1] : sig
        Meta.isexpr(sig, :call) && sig.args[1] in names && Core.eval(Base, x)
    end
end
defs("essentials.jl", (:isvatuple,))
defs("runtime_internals.jl", (:fieldcount, :datatype_fieldcount))
include("effects.jl")
