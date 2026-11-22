# W-170 (E-538), candidate 6: the stack where getindex(::SimpleVector, ::UnitRange{Int}) is first compiled at the ODE
# port's load (the program's file included, as E-536's session's load phase): the method's instance is found, its code instance invalidated so that the first call compiles it, and
# the call is caught by a method of the same signature that prints the stack once. (A probe; it redefines nothing
# of the library.)
const SEEN = Ref(false)
@eval Base function getindex(v::Core.SimpleVector, r::UnitRange{Int64})
    if !$(SEEN)[]
        $(SEEN)[] = true
        st = stacktrace()
        println("R getindex(::SimpleVector, ::UnitRange) first called from:")
        for fr in st[2:min(end, 16)]; println("R   ", fr); end
    end
    return Core.svec(Any[v[i] for i in r]...)
end
using TraitWorld, TraitDifferentialEquations
println("R -- after using")
include(joinpath(@__DIR__, "..", "w158", "port", "apps", "ode_cb.jl"))
println("R -- after the program's file")
