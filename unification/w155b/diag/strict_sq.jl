# W-155b: why strict mode's test of a pirate at `abs2` fails on julia-s3 with TraitWorld-s3 (bb4ad00):
# the deep class of `StrictLib.sq` and of what it rests on, edge by edge.
using TraitWorld
module StrictLib
using TraitWorld
@trait_module
@trait SBuf begin
    svals(r::SBuf)::Vector{Float64}
end
struct Buf; v::Vector{Float64}; end
svals(b::Buf) = b.v
@implement SBuf Buf
sq(b::SBuf) = (s = 0.0; for x in svals(b); s += abs2(x); end; s)
end
b = StrictLib.Buf([1.0, 2.0, 3.0])
@show Base.invokelatest(StrictLib.sq, b)
const C = Base.Compiler
flags(ci) = (deep = (ci.flags & 0x10) != 0, facts = (ci.flags & 0x20) != 0)
function show_ci(ci, depth = 0, seen = IdSet{Any}())
    ci in seen && return; push!(seen, ci)
    mi = C.get_ci_mi(ci)
    println("  "^depth, mi.specTypes, " ", flags(ci))
    depth > 3 && return
    for e in ci.edges
        if e isa Core.CodeInstance
            show_ci(e, depth + 1, seen)
        elseif e isa Core.MethodInstance
            println("  "^(depth+1), "MI edge: ", e.specTypes)
        elseif e isa Type
            println("  "^(depth+1), "sig edge: ", e, " fact: ", C.is_fact_sig(e))
        elseif !(e isa Core.Binding)
            println("  "^(depth+1), "other edge: ", typeof(e), " ", e)
        end
    end
end
for m in methods(StrictLib.sq)
    for mi in Base.specializations(m)
        ci = mi.cache
        while true
            show_ci(ci)
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
end
