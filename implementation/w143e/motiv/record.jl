# W-143d (E-540): the compiler's record of three calls (compiler §1.2, §3.1; C-160, open issue 218 (g)): the dispatch
# edges of a caller's CodeInstance, each with whether its signature is a fact.     julia --startup-file=no record.jl
const C = Base.Compiler
p(s::String, c::Char) = findfirst(==(c), s) !== nothing     # `!==` at (Union{Nothing, Int64}, Nothing)
tv() = TypeVar(:T, Char)                                     # TypeVar at (Symbol, Type{Char})
ua(v::TypeVar) = UnionAll(v, Vector{Int})                    # UnionAll at (TypeVar, Type{Vector{Int}})
p("abc", 'b'); tv(); ua(TypeVar(:T))
for (f, tt) in ((p, (String, Char)), (tv, ()), (ua, (TypeVar,)))
    mi = first(m for m in Base.specializations(which(f, tt)) if m isa Core.MethodInstance); ci = mi.cache
    println("== ", f, tt)
    for (sig, item) in C.ForwardToBackedgeIterator(ci.edges)
        item isa Core.MethodInstance || item isa Core.MethodTable || continue
        s = sig isa C.CallSigBackedge ? sig.sig : item isa Core.MethodTable ? sig : item.specTypes
        nm = string(Base.unwrap_unionall(s).parameters[1])
        (occursin("!==", nm) || occursin("TypeVar", nm) || occursin("UnionAll", nm)) || continue
        println("   ", sig isa C.CallSigBackedge ? "call-signature " : item isa Core.MethodTable ? "method table   " : "instance       ",
                s, "  fact: ", C.is_fact_sig(s))
    end
end
