# W-158 (E-510): a trimmed program with a call at a value known only by its trait (a box's object) where the
# member's type chooses the method: at a trait (Named), at a concrete type (Circle), at a family (Rec). Each method
# is reached by a member. `julia --project=<TraitWorld> apps/choice.jl` runs `main` in a session.
using TraitWorld
@trait Shape begin
    area(s::Shape)::Float64
end
@trait Named begin
    name(s::Named)::String
end
struct Square; a::Float64; end
struct Circle; r::Float64; end
struct Rec{F}; f::F; end
area(s::Square) = s.a^2
area(c::Circle) = 3.0 * c.r^2
area(r::Rec) = 1.0
name(s::Square) = "square"
@implement Shape Square
@implement Shape Circle
@implement Shape Rec{F} where {F}
@implement Named Square
describe(@nospecialize(x)) = "a shape"
describe(x::Named) = name(x)
kind(@nospecialize(x)) = 1
kind(x::Circle) = 2
inner(@nospecialize(x)) = 0.0
inner(r::Rec) = Float64(r.f)
report(d::Dynamic{Shape}) = (describe(unwrap(d)), kind(unwrap(d)), inner(unwrap(d)) + area(d))
function (@main)(args::Vector{String})::Cint
    n = length(args) + 2
    v = Dynamic{Shape}[Dynamic{Shape}(Square(Float64(n))), Dynamic{Shape}(Circle(1.0)), Dynamic{Shape}(Rec(n))]
    for d in v
        a, b, c = report(d)
        println(Core.stdout, a, " ", b, " ", c)
    end
    return 0
end
