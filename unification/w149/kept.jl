# W-149 (traits §7.8): `Kept{X}`. The same lines give the same answers whoever stores; the attribute is
# carried; what the two `convert` methods cost at the library's load is measured apart (kept_load.jl).
# Run from TraitWorld-unified: julia --startup-file=no --project=. ../experiments/unification/w149/kept.jl
using TraitWorld
module M
using TraitWorld
@trait_module
export Shape, Scalable, Circle, Scene, add!, area, total, which_code
@trait Shape begin
    area(s::Shape)::Float64
end
@trait Scalable
struct Circle; r::Float64; end
area(c::Circle) = 3.14 * c.r^2
@implement Shape Circle
@implement Scalable Circle
struct Scene; shapes::Vector{Kept{Shape}}; end
add!(sc::Scene, s::Shape) = (push!(sc.shapes, keep(s)); sc)
@open which_code(s::Shape) = typeof(s)                       # the type the code was compiled for
total(sc::Scene) = sum(k -> kept_call(area, k), sc.shapes)
end
using .M
known(sc) = (add!(sc, Circle(1.0)); sc)
unknown(sc, xs::Vector{Any}) = (add!(sc, xs[1]); sc)
a = known(Scene(Kept{Shape}[])); b = unknown(Scene(Kept{Shape}[]), Any[Circle(1.0)])
for (name, sc) in (("typed code", a), ("untyped code", b))
    k = sc.shapes[1]
    println(rpad(name, 13), ": stored ", typeof(k), ", dynamic ", isdynamic(k), "; unwrap isa Scalable ", unwrap(k) isa Scalable,
            "; k isa Scalable ", k isa Scalable, "; k[] is ", typeof(k[]),
            "; code for ", kept_call(which_code, k), "; total ", total(sc))
end
v = Shape[]; push!(v, unwrap(a.shapes[1])); push!(v, unwrap(b.shapes[1]))
println("unwrapped into Vector{Shape}: ", typeof.(v))
println("a Kept into Vector{Shape}: ", try push!(v, a.shapes[1]); "stored" catch e; typeof(e) end)
ms = [mi.specTypes for mi in Base.specializations(only(methods(M.which_code)))]
println("which_code compiled at: ", ms)
