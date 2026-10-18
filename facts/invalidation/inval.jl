# Which definitions invalidate compiled code: stock inference against the facts mode.
# Run:  julia inval.jl                         (stock behaviour)
#       JULIA_FACTS_COMPILER=1 julia --project=<factscompiler/env> inval.jl   (facts mode)
const FACTS = false
if FACTS
    using Compiler
    Compiler.activate!(; reflection = true, codegen = true)
end
println("mode = ", get(ENV, "JULIA_COMPILE_BY_FACTS", "image") , "  julia ", VERSION, "  ", Base.julia_cmd().exec[1])

# All CodeInstances of f at exactly `types`, with their validity.
function cis(f, types)
    sig = Tuple{typeof(f), types...}
    out = []
    for m in methods(f)
        for mi in Base.specializations(m)
            mi.specTypes === sig || continue
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci !== nothing
                push!(out, (valid = ci.max_world == typemax(UInt), min = ci.min_world, max = ci.max_world))
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    out
end
function report(label, f, types)
    v = cis(f, types)
    nvalid = count(c -> c.valid, v)
    println(rpad(label, 62), " CodeInstances: ", length(v), "  valid: ", nvalid,
            nvalid == 0 && !isempty(v) ? "   <-- INVALIDATED" : "")
end
rt(f, types) = Base.infer_return_type(f, types)

# S1: an owned method on an owned type widens a call made at an abstract signature (one match).
module Lib1; foo(x::Int) = 1; caller(v::Vector{Any}) = foo(v[1]); end
Lib1.caller(Any[1])
println("S1 inferred result of caller: ", rt(Lib1.caller, (Vector{Any},)))
report("S1 before", Lib1.caller, (Vector{Any},))
module Other1; struct T end; Main.Lib1.foo(::T) = 2; end           # Other1 owns T: no pirate
report("S1 after Other1 adds foo(::Other1.T)", Lib1.caller, (Vector{Any},))

# S2: speculation over an abstract container (union split, 2 methods <= max_methods); a new subtype by its owner.
module Lib2
abstract type Shape end
struct A <: Shape end; struct B <: Shape end
area(::A) = 1.0; area(::B) = 2.0
function total(v::Vector{Shape}); s = 0.0; for x in v; s += area(x); end; s; end
end
Lib2.total(Lib2.Shape[Lib2.A(), Lib2.B()])
println("S2 inferred result of total: ", rt(Lib2.total, (Vector{Lib2.Shape},)))
report("S2 before", Lib2.total, (Vector{Lib2.Shape},))
module Other2; struct C <: Main.Lib2.Shape end; Main.Lib2.area(::C) = 3.0; end   # Other2 owns C: no pirate
report("S2 after Other2 adds area(::Other2.C)", Lib2.total, (Vector{Lib2.Shape},))

# S3: a result decided by inference (return_type through map over an empty abstract vector).
module Lib3; w(x::Float64) = x; f3(xs::Vector{Real}) = map(w, xs); end
println("S3 f3(Real[]) returns ", typeof(Lib3.f3(Real[])))
report("S3 before", Lib3.f3, (Vector{Real},))
module Other3; struct NR <: Real end; Main.Lib3.w(::NR) = "s"; end         # Other3 owns NR: no pirate
report("S3 after Other3 adds w(::Other3.NR)", Lib3.f3, (Vector{Real},))
println("S3 f3(Real[]) now returns ", typeof(Lib3.f3(Real[])))

# S4: a stakeholder (the function's owner, as its package extension would) adds a more specific method at a concrete fact.
module Lib4; bar(x::Integer) = 1; c4(x::Int) = bar(x); end
Lib4.c4(1)
report("S4 before", Lib4.c4, (Int,))
Lib4.eval(:(bar(x::Int) = 2))
report("S4 after Lib4 adds bar(::Int) (stakeholder)", Lib4.c4, (Int,))

# S5: a pirate that wins at a concrete fact; S6: a pirate that loses there.
module Lib5; baz(x::Integer) = 1; c5(x::Int) = baz(x); end
Lib5.c5(1)
report("S5 before", Lib5.c5, (Int,))
module Pirate5; Main.Lib5.baz(x::Signed) = 99; end                        # owns neither baz nor Signed: pirate, wins at baz(::Int)
report("S5 after Pirate5 adds baz(::Signed) (winning pirate)", Lib5.c5, (Int,))
Lib5.c5(1)
report("S6 recompiled", Lib5.c5, (Int,))
module Pirate6; Main.Lib5.baz(x::Real) = 7; end                           # pirate, loses at baz(::Int)
report("S6 after Pirate6 adds baz(::Real) (losing pirate)", Lib5.c5, (Int,))

# S7: a binding, not a method: redefining a const the code read.
module Lib7; const K = 1; g7() = K + 1; end
Lib7.g7()
report("S7 before", Lib7.g7, ())
Core.eval(Lib7, :(const K = 2))
report("S7 after Lib7 redefines const K", Lib7.g7, ())

# S8: a kind (a type passed as a value) at a call of an owned function; a new type by another owner.
module Lib8; make(::Type{Int}) = 0; c8(T::DataType) = make(T); end
Lib8.c8(Int)
println("S8 inferred result of c8: ", rt(Lib8.c8, (DataType,)))
report("S8 before", Lib8.c8, (DataType,))
module Other8; struct U end; Main.Lib8.make(::Type{U}) = 1; end           # Other8 owns U: no pirate
report("S8 after Other8 adds make(::Type{Other8.U})", Lib8.c8, (DataType,))

# Values: map over an empty container of an abstract element type (design review, finding 1)
module V; g(x::Real) = 1.0; f2(x::Real) = g(x); end
println("map(f2, Real[]) :: ", typeof(map(V.f2, Real[])), "   broadcast: ", typeof(V.f2.(Real[])),
        "   promote_op: ", Base.promote_op(V.f2, Real))
println("facts mode of a new interpreter: ", Base.Compiler.NativeInterpreter().facts,
        "   image default: ", Base.Compiler.FACTS_IMAGE[])
