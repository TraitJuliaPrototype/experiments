# W-158 (E-510): a call at a value known only by its trait (a box's object) where the member's type chooses the
# method. `PATCH=1` lays the worktree's compiler change over the session's (`cc_patch`), so the build's check run
# in the session reads it. Run: $JN --project=<TraitWorld> probes/choice.jl
if get(ENV, "PATCH", "0") == "1"
    include(joinpath(@__DIR__, "..", "..", "w156", "tools", "cc_patch.jl"))
    cc_patch(joinpath(@__DIR__, "..", "..", "..", "..", "wt", "w158-julia", "Compiler", "src", "abstractinterpretation.jl"),
             [:closed_choice_bits, :abstract_call_gf_by_type])
end
using TraitWorld
@trait Shape8 begin
    area8(s::Shape8)::Float64
end
@trait Named8 begin
    name8(s::Named8)::String
end
struct Sq8; a::Float64; end
struct Ci8; r::Float64; end
struct Rec8{F}; f::F; end                     # a family, a member by its pattern (as `ODEFunction` of `Callable`)
area8(s::Sq8) = s.a^2
area8(c::Ci8) = 3.0 * c.r^2
area8(r::Rec8) = 1.0
name8(s::Sq8) = "square"
@implement Shape8 Sq8
@implement Shape8 Ci8
@implement Shape8 Rec8{F} where {F}
@implement Named8 Sq8
# the member's type chooses the method: at a trait (served at the set instance, once), at a concrete type, and
# at a family whose method reads the object's fields (the ODE port's `_problem_of(k, f::ODEFunction, …)`)
describe8(@nospecialize(x)) = "a shape"
describe8(x::Named8) = name8(x)
kind8(@nospecialize(x)) = 1
kind8(x::Ci8) = 2
inner8(@nospecialize(x)) = 0.0
inner8(r::Rec8) = Float64(length(string(r.f)))
report8(d::Dynamic{Shape8}) = (describe8(unwrap(d)), kind8(unwrap(d)), inner8(unwrap(d)) + area8(d))
function choice8(n::Int)
    v = Dynamic{Shape8}[Dynamic{Shape8}(Sq8(Float64(n))), Dynamic{Shape8}(Ci8(1.0))]
    s = 0.0; k = 0; t = ""
    for d in v
        a, b, c = report8(d)
        t *= a; k += b; s += c
    end
    return (t, k, s)
end
if abspath(PROGRAM_FILE) == @__FILE__
    r = verify_main(choice8, (Int,))
    println("holes: ", length(r.holes))
    for h in r.holes
        println("  ", h.kind, " ", h.file, ":", h.line, " ", h.call)
    end
    println("fully typed: ", isfullytyped(fully_typed(choice8, (Int,))))
    println("result: ", choice8(2))
end
