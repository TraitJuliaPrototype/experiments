# W-170 (E-538), candidate 6: the stacks of the first calls, at the ODE program's load (`using`, then the program's
# file, as E-536's load phase), of instances the load compiles: a method of the same signature put in front of
# Base's prints the caller once and calls on. (A probe; nothing of the library is changed.)
const SEEN = Set{String}()
function report(what)
    what in SEEN && return
    push!(SEEN, what)
    println("R $what first called from:")
    for fr in stacktrace()[3:min(end, 12)]; println("R   ", fr); end
end
@eval Base function iterate(e::Iterators.Enumerate{Vector{Symbol}}, state = (1,))
    $(report)("iterate(::Enumerate{Vector{Symbol}})")
    n = iterate(e.itr, state[2:end]...)
    n === nothing && return n
    return (state[1], n[1]), (state[1] + 1, n[2])
end
using TraitWorld, TraitDifferentialEquations
println("R -- after using")
include(joinpath(@__DIR__, "..", "w158", "port", "apps", "ode_cb.jl"))
println("R -- after the program's file")
