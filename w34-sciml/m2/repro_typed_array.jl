# E-158 finding: inside a trait module, a parametric trait's name as a typed array literal's element
# type, `X{P}[]`, is not taken as `Kept{X{P}}` (traits §7.2: `Column[]` means `Vector{Kept{Column}}`);
# the vector's element type is the trait itself, and pushing a conforming value fails at `convert`.
using TraitWorld
@trait_module module TA
using TraitWorld
export Shape, Plain
@trait Shape{P} begin
    area(s::Shape{P}, p::P)::Float64
end
@trait Plain begin
    width(s::Plain)::Float64
end
struct Sq end
area(s::Sq, p::Float64) = p^2
width(s::Sq) = 1.0
@implement Shape{Float64} Sq
@implement Plain Sq
bare() = Plain[]
const_param() = Shape{Float64}[]
where_param(::Type{P}) where {P} = Shape{P}[]
field_vec() = Vector{Shape{Float64}}()
struct Holder{P}
    v::Vector{Shape{P}}
end
holder(::Type{P}) where {P} = Holder{P}(Kept{Shape{P}}[])
end
for (lbl, f) in (("Plain[] (no parameters)", () -> TA.bare()), ("Shape{Float64}[] (a constant parameter)", () -> TA.const_param()),
                 ("Shape{P}[] (a where variable)", () -> TA.where_param(Float64)), ("Vector{Shape{Float64}}()", () -> TA.field_vec()),
                 ("a struct field Vector{Shape{P}}", () -> TA.holder(Float64).v))
    v = f()
    r = try push!(v, TA.Sq()); "push! works" catch e; "push! fails: " * string(typeof(e)) end
    println(rpad(lbl, 42), " eltype ", eltype(v), "; ", r)
end
