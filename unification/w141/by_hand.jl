# E-367, stage 2 and 3 (W-141), R9: what a membership's method gives the library for nothing.
# Run from TraitDifferentialEquations-unified: julia --startup-file=no --project=. ../experiments/unification/w141/by_hand.jl
using TraitWorld, TraitDifferentialEquations
# (1) the method's piracy rule against the membership's: every membership of the session
ms = methods(Core.implements)
println("memberships: ", length(ms), "; owned by the method's rule: ", count(TraitWorld.owned_method, ms))
for m in ms
    TraitWorld.owned_method(m) || println("  not owned by the method's rule: ", m.sig, " in ", m.module)
end
# (2) a third party's membership, written as a method
module Third
struct Mine end
end
m = (Core.eval(Third, :(Core.implements(::Type{$(TraitWorld.HasLength)}, ::Type{Rational{Int}}) = nothing)); nothing)
pir = only(methods(Core.implements, Tuple{Type{TraitWorld.HasLength}, Type{Rational{Int}}}))
println("a third party's membership by hand: owned ", TraitWorld.owned_method(pir), ", module ", pir.module)
# (3) a membership written by hand for a type that does not serve the contract: when is it found?
@trait Sized begin
    size_of(s::Sized)::Int
end
struct Good; n::Int; end
size_of(g::Good) = g.n
struct Bad end
Core.implements(::Type{Sized}, ::Type{Good}) = nothing
Core.implements(::Type{Sized}, ::Type{Bad}) = nothing
total(s::Sized) = size_of(s) + 1
println("by hand, serving the contract: ", total(Good(3)))
r = try total(Bad()) catch err; err end
println("by hand, not serving it: ", typeof(r), ": ", first(sprint(showerror, r), 160))
