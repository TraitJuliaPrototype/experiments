# The examples of traits reference §10.1–10.4 (BaseTraits), run as written, with checks.
#     ./run.sh product --project=. reference_examples.jl
using TraitWorld, Test

@trait_module module Stats
using TraitWorld                        # brings BaseTraits' names: Iterable, Indexable, Keyed, …
mean(xs::(Iterable{Float64}, HasLength)) = (s = 0.0; for x in xs; s += x; end; s / length(xs))
end

@trait_module module Geometry
using TraitWorld
export Shape, area, total
@trait Shape begin
    area(s::Shape)::Float64
end
total(shapes::Iterable{Shape}) = (s = 0.0; for x in shapes; s += area(x); end; s)
end

struct Circle; r::Float64; end
struct Square; a::Float64; end
Geometry.area(c::Circle) = 3.0 * c.r^2
Geometry.area(s::Square) = s.a^2
@implement Geometry.Shape Circle
@implement Geometry.Shape Square

@trait_module module Cells
using TraitWorld
export Cell, isnum
@trait Cell begin
    isnum(c::Cell)::Bool
end
@implement Cell Int begin isnum(c) = true end
@implement Cell String begin isnum(c) = false end
end
using .Cells

@testset "traits reference §10.1–10.4" begin
    @test Stats.mean([1.0, 2.0, 6.0]) == 3.0                                       # §10.1
    v = Any[Circle(1.0), Square(2.0)]                                              # §10.3
    @test Geometry.total(DynamicItems{Geometry.Shape}(v)) == 7.0
    w = collect(DynamicItems{Geometry.Shape}(v))
    @test w isa Vector{Dynamic{Geometry.Shape}} && Geometry.total(w) == 7.0         # §10.2: a Vector{Dynamic{Shape}} conforms
    d = Dict{String, Any}("c" => Circle(1.0), "s" => Square(1.0))
    @test conforms(typeof(DynamicValues{Geometry.Shape}(d)), Keyed{String, Dynamic{Geometry.Shape}})
    u = Any[1, "a", 2]
    retain!(isnum, DynamicItems{Cell}(u))                                          # §10.4
    @test u == Any[1, 2]
    @test_throws TraitBoundError Geometry.total(DynamicItems{Geometry.Shape}(Any[Circle(1.0), 2.5]))   # §10.3: fails when read
end
