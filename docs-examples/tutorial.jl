# The examples of writeup/intro/traits-by-example.md, in the page's order, with checks of the
# results the page states. Run from TraitWorld-unified/ on the unified build (see README.md):
#   JULIA_PKG_OFFLINE=true nice -n 19 ../julia-unified/julia --project=. --startup-file=no ../experiments/docs-examples/tutorial.jl
include(joinpath(@__DIR__, "common.jl"))
using TraitWorld

# --- §1–§12: the library, in one trait module --------------------------------------------------

module Geometry
using TraitWorld
@trait_module
export Shape, area, perimeter, describe, ratio, bigger, title, Placed, move!, Named, greet, report,
       fits, scaled_area, largest, kind, Scalable, scale, doubled, nudged, Scene, add!, totalarea

# §2
@trait Shape begin
    area(s::Shape)::Float64
    perimeter(s::Shape)::Float64
    describe(s::Shape)::String = "a shape of area $(area(s))"
end

# §4
ratio(s::Shape) = area(s) / perimeter(s)
bigger(a::Shape, b::Shape) = area(a) > area(b)
title(s::Shape) = uppercasefirst(describe(s))

# §6
@trait Placed begin
    x::Float64
    y::Float64
end
move!(p::Placed, dx::Float64, dy::Float64) = (p.x += dx; p.y += dy; nothing)

@trait Named begin
    @const name::String
end
greet(n::Named) = "hello, $(n.name)"

# §7
report(s::All{Shape, Placed}) = "$(describe(s)) at ($(s.x), $(s.y))"

# §9
fits(s::Shape; within::Shape = s, margin::Float64 = 0.0) = area(s) + margin <= area(within)
scaled_area(s::Shape, k::Float64 = 2.0) = k^2 * area(s)
largest(ss::Shape...) = maximum(area(s) for s in ss; init = 0.0)

# §10
kind(v::AbstractVector) = "a vector"
kind(s::Shape) = "a shape"
kind(x) = "something else"

# §11
@trait Scalable begin
    scale(s::Scalable, k::Float64)::Self
end
@open doubled(s::Scalable) = like(s, scale(s, 2.0))     # a result of the member's own type: open
@open nudged(p::Placed) = withfields(p; x = p.x + 1.0)

# §12
struct Scene
    shapes::Vector{Shape}
end
Scene() = Scene(Shape[])
add!(sc::Scene, s::Shape) = (push!(sc.shapes, keep(s)); sc)
function totalarea(sc::Scene)
    a = 0.0
    for s in sc.shapes
        a += area(s)
    end
    return a
end
end

using .Geometry

# --- §3: joining a trait ------------------------------------------------------------------------

struct Circle
    r::Float64
end
Geometry.area(c::Circle) = π * c.r^2
Geometry.perimeter(c::Circle) = 2π * c.r
@implement Shape Circle

struct Rect
    w::Float64
    h::Float64
end
@implement Shape Rect begin
    area(r) = r.w * r.h
    perimeter(r) = 2 * (r.w + r.h)
    describe(r) = "a $(r.w) by $(r.h) rectangle"
end

check("§3 area(Circle(1.0)) == 3.141592653589793", area(Circle(1.0)) == 3.141592653589793)
check("§3 describe(Rect(2.0, 3.0))", describe(Rect(2.0, 3.0)) == "a 2.0 by 3.0 rectangle")
check("§3 describe(Circle(1.0)): the default, reached from plain code", describe(Circle(1.0)) == "a shape of area 3.141592653589793")
check("§3 Circle <: Shape", Circle <: Shape)
check("§3 Circle(1.0) isa Shape", Circle(1.0) isa Shape)
check("§3 Int is no Shape", !(Int <: Shape))

# --- §4: methods at a trait ---------------------------------------------------------------------

check("§4 ratio(Circle(1.0)) == 0.5", ratio(Circle(1.0)) == 0.5)
check("§4 ratio(Rect(2.0, 3.0)) == 0.6", ratio(Rect(2.0, 3.0)) == 0.6)
check("§4 bigger(Rect, Circle)", bigger(Rect(2.0, 3.0), Circle(1.0)))
check("§4 title(Circle(1.0))", title(Circle(1.0)) == "A shape of area 3.141592653589793")
check("§4 title(Rect(2.0, 3.0))", title(Rect(2.0, 3.0)) == "A 2.0 by 3.0 rectangle")
circle_ratio(c::Circle) = ratio(c)
check("§4 circle_ratio", circle_ratio(Circle(1.0)) == 0.5)
check("§4 ratio(compiled_for(Circle(1.0)))", ratio(compiled_for(Circle(1.0))) == 0.5)
check("§4 ratio(with_dynamic(Circle(1.0)))", ratio(with_dynamic(Circle(1.0))) == 0.5)

# --- §5: forwarding -----------------------------------------------------------------------------

struct Tile
    label::String
    shape::Rect
end
@implement Shape Tile by shape

struct Window
    frame::Rect
    pane::Rect
end
@implement Shape Window by pane

check("§5 area(Tile(…)) == 2.0", area(Tile("door", Rect(1.0, 2.0))) == 2.0)
check("§5 ratio(Tile(…))", ratio(Tile("door", Rect(1.0, 2.0))) == 1/3)
check("§5 ratio(Window(…))", ratio(Window(Rect(3.0, 3.0), Rect(1.0, 2.0))) == 1/3)
check("§5 describe(Tile(…)): the default, at the field", describe(Tile("door", Rect(1.0, 2.0))) == "a 1.0 by 2.0 rectangle")

# --- §6: fields ---------------------------------------------------------------------------------

mutable struct Sprite
    name::String
    x::Float64
    y::Float64
    body::Circle
end
@implement Placed Sprite
@implement Named Sprite

struct Book
    name::String
    pages::Int
end
@implement Named Book

sp = Sprite("ball", 0.0, 0.0, Circle(0.5))
move!(sp, 1.0, 2.0)
check("§6 move! wrote the user's object", (sp.x, sp.y) == (1.0, 2.0))
check("§6 greet(sp)", greet(sp) == "hello, ball")
check("§6 greet(Book)", greet(Book("Julia", 300)) == "hello, Julia")

struct Frozen
    x::Float64
    y::Float64
end
e = thrown(:(@implement Placed Frozen))
check("§6 a writable field needs a mutable type: ImplementError", e isa ImplementError)

# --- §7: several traits -------------------------------------------------------------------------

@implement Shape Sprite by body
check("§7 report(sp)", report(sp) == "a shape of area 0.7853981633974483 at (1.0, 2.0)")
check("§7 Sprite <: All{Shape, Placed}", Sprite <: All{Shape, Placed})
check("§7 Circle is no All{Shape, Placed}", !(Circle <: All{Shape, Placed}))

# --- §8: overrides fixed at the membership ------------------------------------------------------

e = thrown(:(Geometry.describe(c::Circle) = "a circle"))
check("§8 a later override is refused with ImplementError", e isa ImplementError)
e === nothing || println("MESSAGE §8:\n", msg(e))
check("§8 title(Circle(1.0)) unchanged", title(Circle(1.0)) == "A shape of area 3.141592653589793")

# --- §9: keywords, defaults, varargs ------------------------------------------------------------

check("§9 fits(Circle; within = Rect)", fits(Circle(1.0); within = Rect(2.0, 3.0)))
check("§9 fits(Rect; within = Circle) is false", !fits(Rect(2.0, 3.0); within = Circle(1.0)))
check("§9 scaled_area(Rect(2.0, 3.0)) == 24.0", scaled_area(Rect(2.0, 3.0)) == 24.0)
check("§9 largest of three types", largest(Circle(1.0), Rect(2.0, 3.0), Tile("door", Rect(1.0, 2.0))) == 6.0)
e = outcome(() -> fits(Circle(1.0); margin = 1))
check("§9 margin = 1 raises TypeError", e isa TypeError)
e = outcome(() -> fits(Circle(1.0); within = 42))
check("§9 within = 42 raises TypeError", e isa TypeError)

# --- §10: types first ---------------------------------------------------------------------------

check("§10 kind([1.0, 2.0])", kind([1.0, 2.0]) == "a vector")
check("§10 kind(Circle(1.0))", kind(Circle(1.0)) == "a shape")
check("§10 kind(42)", kind(42) == "something else")

# --- §11: results like the input ----------------------------------------------------------------

@implement Scalable Circle begin
    scale(c, k) = Circle(k * c.r)
end
@implement Scalable Rect begin
    scale(r, k) = Rect(k * r.w, k * r.h)
end
@implement Scalable Tile by shape

check("§11 doubled(Circle(1.0))", doubled(Circle(1.0)) == Circle(2.0))
t2 = doubled(Tile("door", Rect(1.0, 2.0)))
check("§11 doubled(Tile): the label kept", t2 isa Tile && t2.label == "door" && t2.shape == Rect(2.0, 4.0))
n2 = nudged(sp)
check("§11 nudged(sp): a new Sprite", n2 isa Sprite && n2.x == 2.0 && sp.x == 1.0)

# --- §12: collections of mixed types ------------------------------------------------------------

sc = Scene()
add!(sc, Circle(1.0)); add!(sc, Rect(2.0, 3.0)); add!(sc, Tile("door", Rect(1.0, 2.0)))
check("§12 totalarea", totalarea(sc) == π + 6.0 + 2.0)
check("§12 at the prompt the item is kept Dynamic", sc.shapes[1] isa Dynamic{Shape})
add!(sc, compiled_for(Circle(1.0)))
check("§12 a cast to Compiled stores the member itself", sc.shapes[4] isa Circle)
d = Dynamic{Shape}(Circle(2.0))
check("§12 Dynamic{Shape} isa Shape", d isa Shape)
check("§12 area(d)", area(d) == 4π)
check("§12 ratio(d)", ratio(d) == 1.0)
check("§12 unwrap(d)", unwrap(d) == Circle(2.0))
e = outcome(() -> Dynamic{Shape}(42))
check("§12 Dynamic{Shape}(42) raises TypeError", e isa TypeError)

# --- §13: parameters ----------------------------------------------------------------------------

module Signals
using TraitWorld
@trait_module
export Samples, nsamples, sample, total, mean64, transform, sumby, Threshold, countif, Gate, countgate

@trait Samples{T} begin
    T = eltype(Self)
    nsamples(s::Samples)::Int
    sample(s::Samples{T}, i::Int)::T
end
@implement Samples{T} Vector{T} where {T <: Real} begin
    nsamples(s) = length(s)
    sample(s, i) = s[i]
end

function total(s::Samples)
    acc = zero(sample(s, 1))
    for i in 1:nsamples(s)
        acc += sample(s, i)
    end
    return acc
end
mean64(s::Samples{Float64}) = total(s) / nsamples(s)

# §14
function transform(f::Callable{Tuple{Float64}, Float64}, s::Samples{Float64})
    out = Vector{Float64}(undef, nsamples(s))
    for i in 1:nsamples(s)
        out[i] = f(sample(s, i))
    end
    return out
end
function sumby(@specialize(f::Callable{Tuple{Float64}, Float64}), s::Samples{Float64})
    acc = 0.0
    for i in 1:nsamples(s)
        acc += f(sample(s, i))
    end
    return acc
end
struct Threshold
    test::Callable{Tuple{Float64}, Bool}
end
function countif(th::Threshold, s::Samples{Float64})
    n = 0
    for i in 1:nsamples(s)
        th.test(sample(s, i)) && (n += 1)
    end
    return n
end
struct Gate{F <: Callable{Tuple{Float64}, Bool}}
    test::F
end
function countgate(g::Gate, s::Samples{Float64})
    n = 0
    for i in 1:nsamples(s)
        g.test(sample(s, i)) && (n += 1)
    end
    return n
end
end
using .Signals

struct Series{T}
    data::Vector{T}
end
Signals.nsamples(s::Series) = length(s.data)
Signals.sample(s::Series, i::Int) = s.data[i]
Base.eltype(::Type{Series{T}}) where {T} = T
@implement Samples{T} Series{T} where {T}

check("§13 total([1.0, 2.0, 3.5])", total([1.0, 2.0, 3.5]) == 6.5)
check("§13 total([1, 2, 3]) is an Int", total([1, 2, 3]) === 6)
check("§13 total(Series(Float32[1, 2]))", total(Series(Float32[1, 2])) === 3.0f0)
check("§13 mean64(Series([1.0, 4.0]))", mean64(Series([1.0, 4.0])) == 2.5)
check("§13 Vector{Int} <: Samples{Int}", Vector{Int} <: Samples{Int})
e = outcome(() -> mean64([1, 2]))
check("§13 mean64([1, 2]) raises MethodError", e isa MethodError)

struct Odd end
Signals.nsamples(::Odd) = 1
Signals.sample(::Odd, i::Int) = 1.0
e = thrown(:(@implement Samples{Float64} Odd))
check("§13 a stated parameter against its equation: ImplementError", e isa ImplementError)

module Dots
using TraitWorld, ..Signals
@trait_module
export dotp
function dotp(a::Samples{T}, b::Samples{T}) where {T}
    acc = zero(T)
    for i in 1:nsamples(a)
        acc += sample(a, i) * sample(b, i)
    end
    return acc
end
end
using .Dots
check("§13 dotp", dotp([1.0, 2.0], [3.0, 4.0]) == 11.0)
e = outcome(() -> dotp([1.0], [1]))
check("§13 dotp([1.0], [1]) raises MethodError", e isa MethodError)

# --- §14: Callable ------------------------------------------------------------------------------

check("§14 transform(x -> 2x, …)", transform(x -> 2x, [1.0, 2.0]) == [2.0, 4.0])
check("§14 transform(compiled_for(…), …)", transform(compiled_for(x -> x / 2), [1.0]) == [0.5])
check("§14 sumby(abs2, …)", sumby(abs2, [1.0, 2.0]) == 5.0)
check("§14 sumby(with_dynamic(…), …)", sumby(with_dynamic(x -> x + 1), [1.0, 2.0]) == 5.0)
e = outcome(() -> transform(x -> 1, [1.0]))
check("§14 a result of the wrong type raises TypeError", e isa TypeError)
e = outcome(() -> transform(uppercase, [1.0]))
check("§14 a function with no method at Float64 raises MethodError", e isa MethodError)
check("§14 sin isa Callable{Tuple{Float64}, Float64}", sin isa Callable{Tuple{Float64}, Float64})
check("§14 uppercase is no Callable{Tuple{Float64}}", !(uppercase isa Callable{Tuple{Float64}}))

th = Threshold(x -> x > 1.0)
check("§14 countif", countif(th, [0.5, 1.5, 2.5]) == 2)
g1 = Gate(x -> x > 1.0)
g2 = Gate(Dynamic{Callable{Tuple{Float64}, Bool}}(x -> x > 1.0))
check("§14 Gate(f): F is the function's type", !(typeof(g1).parameters[1] <: Dynamic))
check("§14 Gate(Dynamic{…}(f)): F is the Dynamic", typeof(g2).parameters[1] <: Dynamic)
check("§14 countgate", countgate(g1, [0.5, 1.5, 2.5]) == 2 && countgate(g2, [0.5, 1.5, 2.5]) == 2)

# --- §15: abstract types and traits as members --------------------------------------------------

module Seqs
using TraitWorld
@trait_module
export Sequence, Signal, nvalues, value, energy
@trait Sequence begin
    Base.length(s::Sequence)::Int
    Base.getindex(s::Sequence, i::Int)::Float64
end
@implement Sequence AbstractVector{Float64}
@trait Signal begin
    nvalues(s::Signal)::Int
    value(s::Signal, i::Int)::Float64
end
@implement Signal Sequence begin
    nvalues(r) = length(r)
    value(r, i) = r[i]
end
function energy(s::Signal)
    e = 0.0
    for i in 1:nvalues(s)
        e += value(s, i)^2
    end
    return e
end
end
using .Seqs

struct Ring
    vals::Vector{Float64}
end
Base.length(r::Ring) = length(r.vals)
Base.getindex(r::Ring, i::Int) = r.vals[mod1(i, length(r.vals))]
@implement Sequence Ring

check("§15 energy([1.0, 2.0])", energy([1.0, 2.0]) == 5.0)
check("§15 energy(Ring([3.0, 4.0]))", energy(Ring([3.0, 4.0])) == 25.0)
check("§15 Ring <: Signal, transitively", Ring <: Signal)
check("§15 Vector{Float64} <: Signal", Vector{Float64} <: Signal)

# --- §16: when something does not fit -----------------------------------------------------------

struct Square
    side::Int
end
Geometry.area(s::Square) = s.side^2
Geometry.perimeter(s::Square) = 4.0 * s.side
e = thrown(:(@implement Shape Square))
check("§16 a result of the wrong type: ImplementError", e isa ImplementError)
e === nothing || println("MESSAGE §16 Square:\n", msg(e))

struct Dot end
Geometry.area(::Dot) = 0.0
e = thrown(:(@implement Shape Dot))
check("§16 a missing operation: ImplementError", e isa ImplementError)
e === nothing || println("MESSAGE §16 Dot:\n", msg(e))

e = outcome(() -> ratio(42))
check("§16 ratio(42) raises MethodError", e isa MethodError)
e isa Exception && println("MESSAGE §16 ratio(42):\n", msg(e))

e = thrown(:(module Sloppy
    using TraitWorld, ..Geometry
    @trait_module
    halfarea(s::Shape) = area(s) / 2
    outline(s::Shape) = length(s)
    end))
check("§16 an open method in a trait module: TraitUseError", e isa TraitUseError)
e === nothing || println("MESSAGE §16 Sloppy:\n", msg(e))

e = thrown(:(module Meddler
    using TraitWorld
    @trait_module
    Base.sum(x::Vector{Int8}) = 0
    end))
check("§16 a pirate in a trait module: OwnershipError", e isa OwnershipError)
e === nothing || println("MESSAGE §16 Meddler:\n", msg(e))

# --- §17: concreteness and fully typed code -----------------------------------------------------

module Weights
using TraitWorld
@trait_module
export Weighted, weight, wscaled
@trait Weighted begin
    @enforce_concrete_only Self
    weight(w::Weighted)::Float64
end
@implement Weighted AbstractVector{Float64} begin
    weight(a) = sum(a)
end
wscaled(w::Weighted, k::Vector{Any}) = weight(w) * k[1]
end
using .Weights

struct Crate
    data::AbstractVector{Float64}
end
e = thrown(:(@implement Weighted Crate by data))
check("§17 an abstract field refused by @enforce_concrete_only: ImplementError", e isa ImplementError)
e === nothing || println("MESSAGE §17 Crate:\n", msg(e))
struct Box
    data::Vector{Float64}
end
@implement Weighted Box by data
check("§17 Box joins", Box <: Weighted && weight(Box([1.0, 2.0])) == 3.0)

module Strictly
using TraitWorld, ..Signals
@trait_module
export firstsample
@enforce_concrete_only T firstsample(s::Samples{T}) where {T} = sample(s, 1)
end
using .Strictly
check("§17 firstsample([1.5, 2.0])", firstsample([1.5, 2.0]) == 1.5)
e = outcome(() -> firstsample(Real[1.5, 2.0]))
check("§17 firstsample(Real[…]) raises TraitUseError", e isa TraitUseError)

check("§17 totalarea is fully typed", isfullytyped(fully_typed(Geometry.totalarea, (Geometry.Scene,))))
check("§17 wscaled is not", !isfullytyped(fully_typed(Weights.wscaled, (Vector{Float64}, Vector{Any}))))

summary()
