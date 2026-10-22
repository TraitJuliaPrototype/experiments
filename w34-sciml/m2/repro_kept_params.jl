# E-158 finding: a value whose type implements a parametric trait at some parameters is accepted as a
# kept value of the trait at other parameters, `Kept{X{B}}(x)` with `x` implementing only `X{A}`; the
# mismatch surfaces at the first operation (TraitArgumentError), not when the value is kept.
using TraitWorld
@trait_module module KP
using TraitWorld
export Shape, area
@trait Shape{P} begin
    area(s::Shape{P}, p::P)::Float64
end
struct Sq end
area(s::Sq, p::Vector{Float64}) = p[1]^2
@implement Shape{Vector{Float64}} Sq
end
using .KP
println("conforms(Sq, Shape{Vector{Float64}}) = ", conforms(KP.Sq, Shape{Vector{Float64}}))
println("conforms(Sq, Shape{Int}) = ", conforms(KP.Sq, Shape{Int}))
for K in (Kept, Dynamic, Compiled)
    r = try
        k = K{Shape{Int}}(KP.Sq())
        "accepted as $(typeof(k)); area(k, 2): " * (try string(area(k, 2)) catch e; string(typeof(e), ": ", first(split(sprint(showerror, e), '\n'))) end)
    catch e
        "refused: " * string(typeof(e))
    end
    println(K, "{Shape{Int}}(Sq()): ", r)
end
