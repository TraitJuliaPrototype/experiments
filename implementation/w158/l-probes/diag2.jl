# C-157, diagnosis: the flags of the inserted typeassert, and whether codegen keeps it (LLVM IR).
using TraitWorld
module Sig
using TraitWorld
@trait_module
export passes
function passes(tests::Vector{Callable{Tuple{Float64}, Bool}}, x::Float64)
    n = 0
    for t in tests
        t(x) && (n += 1)
    end
    return n
end
end
using .Sig
const T = Vector{Callable{Tuple{Float64}, Bool}}
ci, rt = only(Base.code_typed(passes, (T, Float64)))
CC = Base.Compiler
for (i, st) in enumerate(ci.code)
    if Meta.isexpr(st, :call) && (st.args[1] == GlobalRef(Core, :typeassert))
        f = ci.ssaflags[i]
        println("stmt ", i, ": ", st, " flags ", repr(f),
                " effect_free=", f & CC.IR_FLAG_EFFECT_FREE != 0, " nothrow=", f & CC.IR_FLAG_NOTHROW != 0,
                " consistent=", f & CC.IR_FLAG_CONSISTENT != 0, " refined=", f & CC.IR_FLAG_REFINED != 0,
                " type ", ci.ssavaluetypes[i])
    end
    if Meta.isexpr(st, :call) && st.args[1] isa Core.SSAValue
        println("stmt ", i, ": ", st, " flags ", repr(ci.ssaflags[i]), " type ", ci.ssavaluetypes[i])
    end
end
using InteractiveUtils
io = IOBuffer()
code_llvm(io, passes, (T, Float64); debuginfo = :none)
s = String(take!(io))
println("LLVM mentions typeassert/type_error: ", occursin("typeassert", s) || occursin("type_error", s))
for l in split(s, '\n')
    (occursin("call", l) && (occursin("jl_", l) || occursin("ijl_", l))) && println("  ", strip(l))
end
