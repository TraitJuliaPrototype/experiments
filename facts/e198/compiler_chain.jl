# E-198 part A, case (d): a pirate on a Base function at a signature the compiler's code calls, where code of
# the facts owner (TraitWorld's machinery) calls that compiler code directly. Strict mode must refuse it: the
# chain facts code -> compiler code -> Julia's plain code is walked through (the strict-mode note, §3).
#     JULIA_TW_STRICT=1 julia --project=<TraitWorld> compiler_chain.jl
using TraitWorld
const CC = Base.Compiler
# make the machinery run: a trait module with an implementation checked at its definition
@trait_module module ChainT
using TraitWorld
export Sized, size1, total, Box
@trait Sized begin
    size1(x::Sized)::Int
end
struct Box; n::Int; end
@implement Sized Box begin
    size1(b) = b.n
end
total(s::Sized) = size1(s) + 1
end
@show ChainT.total(ChainT.Box(2))
plain_of_julia(m) = m isa Method && TraitWorld.owner(m.module) === :Julia && ccall(:jl_method_is_plain, Cint, (Any,), m) == 0
"Chains facts CI -> compiler CI -> Julia's plain CI at a signature of Base and Core types only."
function chains(limit)
    out = []
    Base.visit(Core.methodtable) do m
        length(out) >= limit && return
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
            ci = mi.cache
            while ci isa Core.CodeInstance
                if ci.owner === :facts && isdefined(ci, :edges) && ci.max_world == typemax(UInt)
                    for e in ci.edges
                        e isa Core.CodeInstance && e.owner === nothing || continue
                        cm = Core.Compiler.get_ci_mi(e).def
                        cm isa Method && ccall(:jl_method_is_plain, Cint, (Any,), cm) != 0 || continue
                        isdefined(e, :edges) || continue
                        for b in e.edges
                            b isa Core.CodeInstance && b.owner === nothing && b.max_world == typemax(UInt) || continue
                            bm = Core.Compiler.get_ci_mi(b)
                            plain_of_julia(bm.def) || continue
                            sig = bm.specTypes
                            sig isa DataType && all(t -> t isa DataType && TraitWorld.owner(t.name.module) === :Julia, sig.parameters) || continue
                            ft = sig.parameters[1]
                            isdefined(ft, :instance) || continue
                            push!(out, (ci, e, b, sig))
                            length(out) >= limit && return
                        end
                    end
                end
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    return out
end
cs = chains(3)
println("C chains found: ", length(cs))
for (ci, e, b, sig) in cs
    f = sig.parameters[1].instance
    args = [Symbol("a", i) for i in 2:length(sig.parameters)]
    ex = :(function $(GlobalRef(parentmodule(f), nameof(f)))($([:($a::$(sig.parameters[i+1])) for (i, a) in enumerate(args)]...)) error("pirate") end)
    r = try
        Core.eval(Main, ex)
        "DEFINED (not refused)"
    catch err
        err isa TraitWorld.PirateError ? "refused: PirateError" : "error: " * first(sprint(showerror, err), 120)
    end
    println("R ", sig, " (compiler ", Core.Compiler.get_ci_mi(e).def.name, ", facts code ", Core.Compiler.get_ci_mi(ci).def.name, "): ", r)
end
