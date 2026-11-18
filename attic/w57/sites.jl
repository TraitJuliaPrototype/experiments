# E-167: where the padding chain still holds run-time sites under the facts interpreter: the
# withdrawn-assertion log, and each frame's generic calls whose signature is no fact signature
# (Compiler.is_fact_sig), unoptimized, at the frame's own argument types.
using ForwardDiff
const Compiler = Base.Compiler
const D1 = ForwardDiff.Dual{ForwardDiff.Tag{typeof(sin), Float64}, Float64, 1}
const P1 = ForwardDiff.Partials{1, Float64}
interp = Compiler.NativeInterpreter(; facts = true)
function argtype(ci, x)
    x isa Core.SSAValue && return Compiler.widenconst(ci.ssavaluetypes[x.id])
    x isa Core.Argument && return Compiler.widenconst(ci.slottypes[x.n])
    x isa Core.SlotNumber && return Compiler.widenconst(ci.slottypes[x.id])
    x isa GlobalRef && return isdefinedglobal(x.mod, x.name) ? Core.Typeof(getglobal(x.mod, x.name)) : Any
    x isa QuoteNode && return Core.Typeof(x.value)
    return Core.Typeof(x)
end
function sites(f, tt)
    println("== ", f, tt)
    Compiler.WITHDRAWN_LOG[] = true
    r = Base.code_typed(f, tt; interp, optimize = false)
    Compiler.WITHDRAWN_LOG[] = false
    for (ci, rt) in r, (i, st) in enumerate(ci.code)
        Meta.isexpr(st, :call) || continue
        ts = Any[argtype(ci, a) for a in st.args]
        ts[1] <: Core.Builtin && continue
        sig = Tuple{ts...}
        Compiler.is_fact_sig(sig) && continue
        println("  ", i, ": ", st, "   at ", sig)
    end
end
sites(Base.isvatuple, (Union{Type{Float64}, Type{P1}},))
sites(Base.isvatuple, (Any,))
sites(Base.fieldcount, (Union{Type{Float64}, Type{P1}},))
sites(Base.fieldcount, (Any,))
sites(Base.datatype_fieldcount, (DataType,))
sites(Base.padding!, (Vector{Base.Padding}, DataType, Int))
sites(Base.padding, (Type{D1},))
sites(Base.packedsize, (Type{D1},))
sites(Base.CyclePadding, (DataType,))
sites(Base.array_subpadding, (Type{D1}, Type{Float64}))
