# W-166, second part (compiler §7.6, C-150): a loop hands five members of a trait over as the wrapper `compiled_for(x)`
# and calls a function at each. In a closed build the wrapper of a value known only by its trait is known by its
# members' wrappers, however many, and the call that takes it branches over them, each branch the call at `Compiled{M}`.
module Five
using TraitWorld
@trait_module
export Sh5, ar5
@trait Sh5 begin
    ar5(s::Sh5)::Float64
end
end
using .Five, TraitWorld
struct Q1; x::Float64; end
struct Q2; x::Float64; end
struct Q3; x::Float64; end
struct Q4; x::Int; end
struct Q5; x::Float32; end
Five.ar5(s::Q1) = 1.0 * s.x
Five.ar5(s::Q2) = 2.0 * s.x
Five.ar5(s::Q3) = 3.0 * s.x
Five.ar5(s::Q4) = 4.0 * s.x
Five.ar5(s::Q5) = 5.0 * Float64(s.x)
@implement Sh5 Q1
@implement Sh5 Q2
@implement Sh5 Q3
@implement Sh5 Q4
@implement Sh5 Q5
# a function at the trait, compiled per member through the wrapper; and one with a method at a member's wrapper
scaled(s::Sh5, k::Float64) = k * ar5(s)
label(w::Compiled) = "float"
label(w::Compiled{Q4}) = "int"
function total(v::Vector{Sh5})
    t = 0.0
    for s in v
        w = compiled_for(s)
        t += scaled(w, 2.0)::Float64
        println(Core.stdout, label(w)::String, " ", ar5(w))
    end
    return t
end
function (@main)(args::Vector{String})::Cint
    v = Sh5[Q1(1.0), Q2(1.0), Q3(1.0), Q4(1), Q5(1.0f0)]
    println(Core.stdout, "total ", total(v))
    return 0
end
