# BaseBenchmarks' raytracer written as idiomatic Julia: concrete children (no dynamic dispatch),
# optionally an immutable Hit (no allocation per hit). Same scene, same rays, same result.
using BaseBenchmarks
include(joinpath(pkgdir(BaseBenchmarks), "src", "problem", "Raytracer.jl"))
for immut in (false, true)
    name = immut ? :RTConcreteImm : :RTConcrete
    src = """
    module $name
    const DELTA = sqrt(eps(Float64))
    struct Vec; x::Float64; y::Float64; z::Float64; end
    Base.:+(a::Vec, b::Vec) = Vec(a.x+b.x, a.y+b.y, a.z+b.z)
    Base.:-(a::Vec, b::Vec) = Vec(a.x-b.x, a.y-b.y, a.z-b.z)
    Base.:*(a::Float64, b::Vec) = Vec(a*b.x, a*b.y, a*b.z)
    Base.:*(a::Int, b::Vec) = Vec(a*b.x, a*b.y, a*b.z)
    dot(a::Vec, b::Vec) = (a.x*b.x + a.y*b.y + a.z*b.z)
    unitize(a::Vec) = (1. / sqrt(dot(a, a)) * a)
    struct Ray; orig::Vec; dir::Vec; end
    $(immut ? "struct" : "mutable struct") Hit; lambda::Float64; normal::Vec; end
    struct Sphere; center::Vec; radius::Float64; end
    struct Group; bound::Sphere; spheres::Vector{Sphere}; groups::Vector{Group}; end
    function raysphere(s::Sphere, ray::Ray)
        v = s.center - ray.orig; b = dot(v, ray.dir)
        disc = b*b - dot(v, v) + s.radius*s.radius
        if disc >= 0
            d = sqrt(disc); t2 = b + d
            if t2 >= 0
                t1 = b - d
                return t1 > 0 ? t1 : t2
            end
        end
        return Inf
    end
    function intersect(s::Sphere, i::Hit, ray::Ray)
        l = raysphere(s, ray)
        l >= i.lambda ? i : Hit(l, unitize(ray.orig + l * ray.dir - s.center))
    end
    function intersect(g::Group, i::Hit, ray::Ray)
        l = raysphere(g.bound, ray)
        l >= i.lambda && return i
        for s in g.spheres; i = intersect(s, i, ray); end
        for h in g.groups; i = intersect(h, i, ray); end
        return i
    end
    function traceray(light::Vec, ray::Ray, scene)
        i = intersect(scene, Hit(Inf, Vec(0.,0.,0.)), ray)
        i.lambda == Inf && return 0.0
        o = ray.orig + i.lambda*ray.dir + DELTA*i.normal
        g = dot(i.normal, light)
        g >= 0 && return 0.0
        si = intersect(scene, Hit(Inf, Vec(0.,0.,0.)), Ray(o, -1*light))
        return si.lambda == Inf ? -g : 0.0
    end
    function create(level, c::Vec, r)
        level == 1 && return Sphere(c, r)
        group = Group(Sphere(c, 3*r), Sphere[Sphere(c, r)], Group[])
        rn = 3*r/sqrt(12)
        for dz = -1:2:1, dx = -1:2:1
            child = create(level-1, c + Vec(dx*rn, rn, dz*rn), r/2)
            child isa Sphere ? push!(group.spheres, child) : push!(group.groups, child)
        end
        return group
    end
    function perf_raytrace(levels, n, ss)
        scene = create(levels, Vec(0., -1., 0.), 1.)
        light = unitize(Vec(-1., -3., 2.))
        acc = 0.0
        for y in (n-1):-1:0, x in 0:1:(n-1)
            for dx in 0:1:(ss-1), dy in 0:1:(ss-1)
                d = Vec(x + dx/ss - n/2.0, y + dy/ss - n/2.0, Float64(n))
                acc += traceray(light, Ray(Vec(0., 0., -4.0), unitize(d)), scene)
            end
        end
        return acc
    end
    end
    """
    include_string(Main, src)
end
best(f, n) = (f(); minimum(@elapsed(f()) for _ in 1:n))
for (l, f) in (("original (abstract Vector{Scene}, mutable Hit)", () -> Raytracer.perf_raytrace(5, 256, 4)),
               ("concrete children, mutable Hit", () -> RTConcrete.perf_raytrace(5, 256, 4)),
               ("concrete children, immutable Hit", () -> RTConcreteImm.perf_raytrace(5, 256, 4)))
    println(rpad(l, 50), round(best(f, 5) * 1e3, digits = 1), " ms   ", round(@allocated(f()) / 1e6, digits = 1), " MB")
end
println("same image sum: ", RTConcrete.perf_raytrace(3, 32, 1) == RTConcreteImm.perf_raytrace(3, 32, 1))
