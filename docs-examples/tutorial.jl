# The examples of writeup/intro/traits-by-example.md, in the page's order, with checks of the
# results the page states. Run from TraitWorld/ (see README.md):
#   JULIA_PKG_OFFLINE=true nice -n 19 ../julia-1.13/julia --project=. --startup-file=no ../experiments/docs-examples/tutorial.jl
include(joinpath(@__DIR__, "common.jl"))
using TraitWorld

# --- §1–§15: the library, in one trait module ------------------------------------------------

@trait_module module Geometry
using TraitWorld
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
report(s::(Shape, Placed)) = "$(describe(s)) at ($(s.x), $(s.y))"

# §9
fits(s::Shape; within::Shape = s, margin::Float64 = 0.0) = area(s) + margin <= area(within)
scaled_area(s::Shape, k::Float64 = 2.0) = k^2 * area(s)
largest(ss::Shape...) = maximum(area(s) for s in ss; init = 0.0)

# §10
kind(v::AbstractVector) = "a vector"
kind(s::Shape) = "a shape"
kind(x) = "something else"          # untyped, after the bounded method: the fallback

# §11
@trait Scalable begin
    scale(s::Scalable, k::Float64)::Self
end
doubled(s::Scalable)::Like{s} = scale(s, 2.0)
nudged(p::Placed)::Like{p} = withfields(p; x = p.x + 1.0)

# §12
struct Scene
    shapes::Vector{Shape}       # in a trait module: Vector{Dynamic{Shape}}
end
Scene() = Scene(Shape[])
add!(sc::Scene, s::Shape) = (push!(sc.shapes, s); sc)
function totalarea(sc::Scene)
    a = 0.0
    for s in sc.shapes
        a += area(s)
    end
    return a
end
end

using .Geometry

check("§12 a trait's name in a field means its Dynamic", fieldtype(Geometry.Scene, :shapes) === Vector{Dynamic{Geometry.Shape}})

# --- §3 -----------------------------------------------------------------------------------------

struct Circle
    r::Float64
end
Geometry.area(c::Circle) = π * c.r^2
Geometry.perimeter(c::Circle) = 2π * c.r
@implement Shape Circle            # checked now: both operations exist, with the declared results

struct Rect
    w::Float64
    h::Float64
end
@implement Shape Rect begin
    area(r) = r.w * r.h
    perimeter(r) = 2 * (r.w + r.h)
    describe(r) = "a $(r.w) by $(r.h) rectangle"
end

check("§3 area(Circle(1.0))", area(Circle(1.0)) == 3.141592653589793)
check("§3 describe(Rect(2.0, 3.0)), Rect's own method", describe(Rect(2.0, 3.0)) == "a 2.0 by 3.0 rectangle")
check("§3 describe(Circle(1.0)) from plain code: MethodError (the default serves trait code)", outcome(() -> describe(Circle(1.0))) isa MethodError)
check("§3 conforms(Circle, Shape)", conforms(Circle, Shape))

# --- §4 -----------------------------------------------------------------------------------------

check("§4 ratio(Circle(1.0))", ratio(Circle(1.0)) == 0.5)
check("§4 ratio(Rect(2.0, 3.0))", ratio(Rect(2.0, 3.0)) == 0.6)
check("§4 bigger(Rect, Circle)", bigger(Rect(2.0, 3.0), Circle(1.0)) === true)
check("§4 title(Circle(1.0)), the default", title(Circle(1.0)) == "A shape of area 3.141592653589793")
check("§4 title(Rect(2.0, 3.0)), the override", title(Rect(2.0, 3.0)) == "A 2.0 by 3.0 rectangle")

# --- §5 -----------------------------------------------------------------------------------------

struct Tile
    label::String
    shape::Rect
end
@implement Shape Tile by shape     # forwards to its field `shape`

struct Window
    frame::Rect
    pane::Rect
end
@implement Shape Window by pane    # two fields conform: name one

check("§5 area(Tile(…)) from plain code has no method", outcome(() -> area(Tile("door", Rect(1.0, 2.0)))) isa MethodError)
check("§5 ratio(Tile(…))", ratio(Tile("door", Rect(1.0, 2.0))) == 0.3333333333333333)
check("§5 ratio(Window(…)) by pane", ratio(Window(Rect(3.0, 3.0), Rect(1.0, 2.0))) == 0.3333333333333333)
e = thrown(quote struct Tile2; label::String; shape::Rect; end; @implement Shape Tile2 end)
check("§5 without by, no field is chosen: the error names `by shape`", e isa ImplementError && occursin("by shape", msg(e)))
e = thrown(quote
    struct TwoRects; a::Rect; b::Rect; end
    @implement Shape TwoRects
end)
check("§5 two conforming fields without `by`: the error names both `by` lines", e isa ImplementError && occursin("by a", msg(e)) && occursin("by b", msg(e)))

# --- §6 -----------------------------------------------------------------------------------------

mutable struct Sprite
    name::String
    x::Float64
    y::Float64
    body::Circle
end
@implement Placed Sprite          # Sprite has `x` and `y`, of type Float64
@implement Named Sprite

struct Book
    title::String
    pages::Int
end
@implement Named Book name => title          # the declared field `name` is stored as `title`

sp = Sprite("ball", 0.0, 0.0, Circle(0.5))
move!(sp, 1.0, 2.0)
check("§6 move! writes the user's object", (sp.x, sp.y) == (1.0, 2.0))
check("§6 greet(sp)", greet(sp) == "hello, ball")
check("§6 greet(Book), a mapped field", greet(Book("Julia", 300)) == "hello, Julia")

# --- §7 -----------------------------------------------------------------------------------------

@implement Shape Sprite by body    # forwards to `body`, a Circle
check("§7 report(sp)", report(sp) == "a shape of area 0.7853981633974483 at (1.0, 2.0)")

# --- §8 -----------------------------------------------------------------------------------------

e = thrown(:(Geometry.describe(c::Circle) = "a circle"))
check("§8 a later override of a default is refused (ImplementError)", e isa ImplementError && occursin("default", msg(e)))
check("§8 the default still serves Circle", title(Circle(1.0)) == "A shape of area 3.141592653589793")

# --- §9 -----------------------------------------------------------------------------------------

check("§9 fits(Circle; within = Rect)", fits(Circle(1.0); within = Rect(2.0, 3.0)) === true)
check("§9 fits(Rect; within = Circle)", fits(Rect(2.0, 3.0); within = Circle(1.0)) === false)
check("§9 scaled_area(Rect(2.0, 3.0)), a positional default", scaled_area(Rect(2.0, 3.0)) == 24.0)
check("§9 largest(…), a vararg of mixed types", largest(Circle(1.0), Rect(2.0, 3.0), Tile("door", Rect(1.0, 2.0))) == 6.0)
check("§9 margin = 1: TypeError", outcome(() -> fits(Circle(1.0); margin = 1)) isa TypeError)
check("§9 within = 42: TraitBoundError", outcome(() -> fits(Circle(1.0); within = 42)) isa TraitBoundError)

# --- §10 ----------------------------------------------------------------------------------------

check("§10 kind([1.0, 2.0])", kind([1.0, 2.0]) == "a vector")
check("§10 kind(Circle(1.0))", kind(Circle(1.0)) == "a shape")
check("§10 kind(42), the fallback", kind(42) == "something else")
e = thrown(quote
    @trait_module module Unrelated
    using TraitWorld, ..Geometry
    f(s::Shape) = 1
    f(p::Placed) = 2
    end
end)
check("§10 unrelated bounds without a joint method: TraitBoundError", e isa TraitBoundError)

# --- §11 ----------------------------------------------------------------------------------------

@implement Scalable Circle begin
    scale(c, k) = Circle(k * c.r)
end
@implement Scalable Rect begin
    scale(r, k) = Rect(k * r.w, k * r.h)
end
@implement Scalable Tile by shape  # forwards to its `shape` field, a Rect

check("§11 doubled(Circle(1.0))", doubled(Circle(1.0)) == Circle(2.0))
t2 = doubled(Tile("door", Rect(1.0, 2.0)))
check("§11 doubled(Tile(…)) keeps the label", t2 isa Tile && t2.label == "door" && t2.shape == Rect(2.0, 4.0))
n2 = nudged(sp)
check("§11 nudged(sp): a new Sprite, sp unchanged", n2 isa Sprite && n2 !== sp && n2.x == 2.0 && n2.y == 2.0 && n2.name == "ball" && sp.x == 1.0)

# --- §12 ----------------------------------------------------------------------------------------

sc = Scene()
add!(sc, Circle(1.0)); add!(sc, Rect(2.0, 3.0)); add!(sc, Tile("door", Rect(1.0, 2.0)))
check("§12 totalarea(sc)", totalarea(sc) == 11.141592653589793)
d = Dynamic{Shape}(Circle(2.0))   # in plain code, write Dynamic out
check("§12 area(d)", area(d) == 12.566370614359172)
check("§12 ratio(d): opened at a bound", ratio(d) == 1.0)
check("§12 totalarea compiled once", length(Base.specializations(only(methods(Geometry.totalarea)))) == 1)
println("      print(d): ", sprint(show, d))

# --- §13–§15: the second library -----------------------------------------------------------------

@trait_module module Signals
using TraitWorld
export Samples, nsamples, sample, total, mean64, transform, sumby, Threshold, countif,
       Sequence, Signal, nvalues, value, energy

# §13
@trait Samples{T} begin
    T = eltype(Self)                     # T is defined by an equation of the receiver type
    nsamples(s::Samples)::Int
    sample(s::Samples{T}, i::Int)::T
end
@implement Samples A where {A <: Vector{<:Real}} begin   # a family: every vector of real numbers
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
mean64(s::Samples{Float64}) = total(s) / nsamples(s)     # the bound fixes T

# §14
function transform(f::Callable{Tuple{Float64}, Float64}, s::Samples{Float64})
    out = Vector{Float64}(undef, nsamples(s))
    for i in 1:nsamples(s)
        out[i] = f(sample(s, i))
    end
    return out
end
function sumby(f::Callable{Tuple{Float64}, Float64, CompiledCall}, s::Samples{Float64})
    acc = 0.0
    for i in 1:nsamples(s)
        acc += f(sample(s, i))
    end
    return acc
end

struct Threshold
    test::DynamicFn{Tuple{Float64}, Bool}
end
function countif(th::Threshold, s::Samples{Float64})
    n = 0
    for i in 1:nsamples(s)
        th.test(sample(s, i)) && (n += 1)
    end
    return n
end

# §15
@trait Sequence begin
    Base.length(s::Sequence)::Int                       # existing functions as operations
    Base.getindex(s::Sequence, i::Int)::Float64
end
@implement Sequence A where {A <: AbstractVector{Float64}}    # by Base's own methods

@trait Signal begin
    nvalues(s::Signal)::Int
    value(s::Signal, i::Int)::Float64
end
@implement Signal R where {R: Sequence} begin                # every Sequence is a Signal
    nvalues(r) = length(r)
    value(r, i) = r[i]
end
energy(s::Signal) = sum(value(s, i)^2 for i in 1:nvalues(s); init = 0.0)
end
using .Signals

# §13
struct Series{T}
    data::Vector{T}
end
Signals.nsamples(s::Series) = length(s.data)
Signals.sample(s::Series, i::Int) = s.data[i]
@implement Samples{T} Series{T} where {T}

check("§13 total([1.0, 2.0, 3.5])", total([1.0, 2.0, 3.5]) == 6.5)
check("§13 total([1, 2, 3]) is an Int", total([1, 2, 3]) === 6)
check("§13 total(Series(Float32[1, 2]))", total(Series(Float32[1, 2])) === 3.0f0)
check("§13 mean64(Series([1.0, 4.0]))", mean64(Series([1.0, 4.0])) == 2.5)
check("§13 mean64([1, 2]): TraitBoundError", outcome(() -> mean64([1, 2])) isa TraitBoundError)

# §14
check("§14 transform(x -> 2x, …)", transform(x -> 2x, [1.0, 2.0]) == [2.0, 4.0])
check("§14 transform(compiled_call(…), …)", transform(compiled_call(x -> x / 2), [1.0]) == [0.5])
check("§14 sumby(abs2, …)", sumby(abs2, [1.0, 2.0]) == 5.0)
check("§14 sumby(dynamic_call(…), …)", sumby(dynamic_call(x -> x + 1), [1.0, 2.0]) == 5.0)
check("§14 a result of the wrong type: TypeError", outcome(() -> transform(x -> 1, [1.0])) isa TypeError)
th = Threshold(dynamic_fn(Tuple{Float64}, Bool, x -> x > 1.0))
check("§14 countif with a stored DynamicFn", countif(th, [0.5, 1.5, 2.5]) == 2)

# §15
struct Ring
    vals::Vector{Float64}
end
Base.length(r::Ring) = length(r.vals)
Base.getindex(r::Ring, i::Int) = r.vals[mod1(i, length(r.vals))]
@implement Signals.Sequence Ring          # Ring's own methods of length and getindex

check("§15 energy([1.0, 2.0])", energy([1.0, 2.0]) == 5.0)
check("§15 energy(Ring([3.0, 4.0])), through the generic implementation", energy(Ring([3.0, 4.0])) == 25.0)

# --- §16 ----------------------------------------------------------------------------------------

e = thrown(quote
    struct Square
        side::Int
    end
    Geometry.area(s::Square) = s.side^2          # an Int
    Geometry.perimeter(s::Square) = 4.0 * s.side
    @implement Shape Square
end)
check("§16 a result of the wrong type: ImplementError", e isa ImplementError && occursin("declared `Float64`", msg(e)))
println("      message: ", first(split(msg(e), '\n')))

e = thrown(quote
    struct Dot end
    Geometry.area(::Dot) = 0.0
    @implement Shape Dot
end)
check("§16 a missing operation: ImplementError naming perimeter", e isa ImplementError && occursin("perimeter", msg(e)))
println("      message: ", first(split(msg(e), '\n')))

e = outcome(() -> ratio(42))
check("§16 ratio(42): MethodError", e isa MethodError)
println("      message: ", replace(first(msg(e), 300), '\n' => " | "))

logs, e = logs_of(quote
    @trait_module module Sloppy
    using TraitWorld, ..Geometry
    halfarea(s::Shape) = area(s) / 2
    outline(s::Shape) = length(s)          # meant: perimeter(s)
    end
end)
check("§16 the library's mistake: a warning at the module's definition", e === nothing && warned(logs, "length"))
check("§16 Sloppy.halfarea works", Main.Sloppy.halfarea(Circle(1.0)) == 1.5707963267948966)
e = outcome(() -> Main.Sloppy.outline(Circle(1.0)))
check("§16 Sloppy.outline: TraitUseError", e isa TraitUseError)
println("      message: ", replace(first(msg(e), 400), '\n' => " | "))

e = thrown(quote
    @trait_module module Meddler
    using TraitWorld
    Base.sum(x::Vector{Int8}) = 0
    end
end)
check("§16 a pirate in a trait module: OwnershipError", e isa OwnershipError)
println("      message: ", first(msg(e), 300))

# printing by bound and key
check("§16 a trait object's type prints as `Shape at Circle`", sprint(show, typeof(TraitWorld.opened(Dynamic{Shape}(Circle(1.0))))) == "Shape at Circle")
check("§16 a Dynamic prints as `Dynamic{Shape} at Circle`", sprint(show, Dynamic{Shape}(Circle(1.0))) == "Dynamic{Shape} at Circle")

# --- §17 ----------------------------------------------------------------------------------------

@trait_module module Weights
using TraitWorld
export Weighted, weight, wscaled
@trait Weighted begin
    @concrete_only
    weight(w::Weighted)::Float64
end
@implement Weighted A where {A <: AbstractVector{Float64}} begin
    weight(a) = sum(a)
end
wscaled(w::Weighted, k::Vector{Any}) = weight(w) * k[1]
end
using .Weights

e = thrown(quote
    struct Crate
        data::AbstractVector{Float64}      # an abstract field type
    end
    @implement Weighted Crate by data
end)
check("§17 an abstract key under @concrete_only: ImplementError", e isa ImplementError && occursin("@concrete_only", msg(e)))
println("      message: ", first(msg(e), 300))
e = thrown(quote
    struct Box
        data::Vector{Float64}
    end
    @implement Weighted Box by data        # fine
end)
check("§17 a concrete key: accepted", e === nothing && wscaled(Main.Box([1.0, 2.0]), Any[2.0]) == 6.0)
check("§17 totalarea is fully typed", isfullytyped(fully_typed(Geometry.totalarea, (Geometry.Scene,))))
check("§17 wscaled is not fully typed", !isfullytyped(fully_typed(Weights.wscaled, (Vector{Float64}, Vector{Any}))))

summary()
