# Raytrace with an open set of primitives (session 28): what each design costs when users can add
# primitive types. Two more types are defined in each "open" variant but not put in the scene, so
# the work is the same; they change only what the compiler knows. TraitWorld's policy.
#     julia --project=benv recovery/rtopen.jl
using TraitWorld, BaseBenchmarks
const SRC = joinpath(pkgdir(BaseBenchmarks), "src", "problem")
include_string(Main, read(joinpath(SRC, "Raytracer.jl"), String))                       # module Raytracer
extra_plain = """
struct Plane <: Scene; n::Vec; d::Float64; end
struct Box <: Scene; lo::Vec; hi::Vec; end
intersect(p::Plane, i::Hit, ray::Ray) = (t = (p.d - dot(p.n, ray.orig)) / dot(p.n, ray.dir); t > 0 && t < i.lambda ? Hit(t, p.n) : i)
intersect(b::Box, i::Hit, ray::Ray) = i
"""
s = replace(read(joinpath(SRC, "Raytracer.jl"), String), r"^module \w+"m => "module Raytracer4")
s = replace(s, r"\nend # module\s*$" => "\n" * extra_plain * "\nend\n")
include_string(Main, s)                                                                 # four Scene types
include(joinpath(@__DIR__, "RTTrait.jl"))
s = replace(read(joinpath(@__DIR__, "RTTrait.jl"), String), "module RTTrait" => "module RTTrait4")
include_string(Main, s)
include(joinpath(@__DIR__, "RTBucket.jl"))
# the users' primitives, declared outside the libraries (as a user's package would)
struct Plane4; n::RTTrait4.Vec; d::Float64; end
struct Box4; lo::RTTrait4.Vec; hi::RTTrait4.Vec; end
@implement RTTrait4.Scene Plane4 begin
    intersect(p, i, ray) = (t = (p.d - RTTrait4.dot(p.n, ray.orig)) / RTTrait4.dot(p.n, ray.dir); t > 0 && t < i.lambda ? RTTrait4.Hit(t, p.n) : i)
end
@implement RTTrait4.Scene Box4 begin
    intersect(b, i, ray) = i
end
struct PlaneB; n::RTBucket.Vec; d::Float64; end
struct BoxB; lo::RTBucket.Vec; hi::RTBucket.Vec; end
@implement RTBucket.Scene PlaneB begin
    intersect(p, i, ray) = (t = (p.d - RTBucket.dot(p.n, ray.orig)) / RTBucket.dot(p.n, ray.dir); t > 0 && t < i.lambda ? RTBucket.Hit(t, p.n) : i)
end
@implement RTBucket.Scene BoxB begin
    intersect(b, i, ray) = i
end
best(f, n) = (f(); minimum(@elapsed(f()) for _ in 1:n))
for (l, f) in (("plain, 2 Scene types (closed by accident)", () -> Raytracer.perf_raytrace(5, 256, 4)),
               ("plain, 4 Scene types", () -> Raytracer4.perf_raytrace(5, 256, 4)),
               ("trait Dynamic{Scene}, 2 conformances", () -> RTTrait.perf_raytrace(5, 256, 4)),
               ("trait Dynamic{Scene}, 4 conformances", () -> RTTrait4.perf_raytrace(5, 256, 4)),
               ("trait, grouped by key, 4 conformances", () -> RTBucket.perf_raytrace(5, 256, 4)))
    println(rpad(l, 44), round(best(f, 5) * 1e3, digits = 1), " ms")
end
