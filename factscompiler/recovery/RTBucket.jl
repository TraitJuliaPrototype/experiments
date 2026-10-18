# BaseBenchmarks' raytracer with an open set of primitives grouped by key: a group keeps one bucket
# per primitive type (a Vector{T}, conforming to `Bucket` as a family), so one dynamic call per
# bucket and a concrete loop inside, instead of one dynamic call per child.
@trait_module module RTBucket
using TraitWorld
export perf_raytrace, Scene, Hit, Ray, Vec

const DELTA = sqrt(eps(Float64))
struct Vec
    x::Float64
    y::Float64
    z::Float64
end
Base.:+(a::Vec, b::Vec) = Vec(a.x+b.x, a.y+b.y, a.z+b.z)
Base.:-(a::Vec, b::Vec) = Vec(a.x-b.x, a.y-b.y, a.z-b.z)
Base.:*(a::Float64, b::Vec) = Vec(a*b.x, a*b.y, a*b.z)
Base.:*(a::Int, b::Vec) = Vec(a*b.x, a*b.y, a*b.z)
Base.:*(a::Vec, b::Float64) = *(b,a)
dot(a::Vec, b::Vec) = (a.x*b.x + a.y*b.y + a.z*b.z)
unitize(a::Vec) = (1. / sqrt(dot(a, a)) * a)
mutable struct Ray
    orig::Vec
    dir::Vec
end
mutable struct Hit
    lambda::Float64
    normal::Vec
end

"A scene primitive (users add their own)."
@trait Scene begin
    intersect(s::Scene, i::Hit, ray::Ray)::Hit
end
"The primitives of one type in a group."
@trait Bucket begin
    intersect_all(b::Bucket, i::Hit, ray::Ray)::Hit
end
@implement Bucket A where {A <: Vector} begin
    function intersect_all(v, i, ray)
        for x in v
            i = intersect(x, i, ray)
        end
        return i
    end
end

struct Sphere
    center::Vec
    radius::Float64
end
function raysphere(s::Sphere, ray::Ray)
    v = s.center - ray.orig
    b = dot(v, ray.dir)
    disc = b*b - dot(v, v) + s.radius*s.radius
    if disc >= 0
        d = sqrt(disc)
        t2 = b + d
        if t2 >= 0
            t1 = b - d
            return t1 > 0 ? t1 : t2
        end
    end
    return Inf
end
struct Group
    bound::Sphere
    buckets::Vector{Dynamic{Bucket}}
end

@implement Scene Sphere begin
    function intersect(s, i, ray)
        l = raysphere(s, ray)
        if l >= i.lambda
            return i
        else
            n = ray.orig + l * ray.dir - s.center
            return Hit(l, unitize(n))
        end
    end
end
@implement Scene Group begin
    function intersect(g, i, ray)
        l = raysphere(g.bound, ray)
        if l >= i.lambda
            return i
        else
            for b in g.buckets
                i = intersect_all(b, i, ray)
            end
            return i
        end
    end
end

function traceray(light::Vec, ray::Ray, scene::Scene)
    i = intersect(scene, Hit(Inf, Vec(0.,0.,0.)), ray)
    if i.lambda == Inf
        return 0.0
    end
    o = ray.orig + i.lambda*ray.dir + DELTA*i.normal
    g = dot(i.normal, light)
    if g >= 0
        return 0.0
    end
    sray = Ray(o, -1*light)
    si = intersect(scene, Hit(Inf, Vec(0.,0.,0.)), sray)
    return si.lambda == Inf ? -g : 0.0
end

"A group from its children: one bucket per type, in order of first appearance."
function group(bound::Sphere, children::Vector{Any})
    types = Any[]; vecs = Any[]
    for c in children
        k = findfirst(T -> T === typeof(c), types)
        if k === nothing
            push!(types, typeof(c)); push!(vecs, Vector{typeof(c)}())
            k = length(types)
        end
        push!(vecs[k], c)
    end
    return Group(bound, Dynamic{Bucket}[Dynamic{Bucket}(v) for v in vecs])
end
function create(level::Int, c::Vec, r::Float64)
    sphere = Sphere(c, r)
    level == 1 && return sphere
    children = Any[sphere]
    rn = 3*r/sqrt(12)
    for dz = -1:2:1
        for dx = -1:2:1
            c2 = c + Vec(dx*rn, rn, dz*rn)
            push!(children, create(level-1, c2, r/2))
        end
    end
    return group(Sphere(c, 3*r), children)
end

function perf_raytrace(levels, n, ss)
    scene = create(levels, Vec(0., -1., 0.), 1.)::Group
    light = unitize(Vec(-1., -3., 2.))
    for y in (n-1):-1:0
        for x in 0:1:(n-1)
            g = 0.
            for dx in 0:1:(ss-1)
                for dy in 0:1:(ss-1)
                    d = Vec(x + dx/ss - n/2.0, y + dy/ss - n/2.0, Float64(n))
                    ray = Ray(Vec(0., 0., -4.0), unitize(d))
                    g += traceray(light, ray, scene);
                end
            end
        end
    end
end
end
