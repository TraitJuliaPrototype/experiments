# W-149 (traits §8.1): storage typed by the trait holds the object. One method of `convert` that gives a
# `Dynamic{X}`'s object where the target is its trait: is it chosen without ambiguity, and what does its
# definition invalidate? Run from TraitWorld-unified: julia --startup-file=no --project=. convert_probe.jl
using TraitWorld
@trait Shape begin
    area(s::Shape)::Float64
end
struct Circle; r::Float64; end
area(c::Circle) = 3.14 * c.r^2
@implement Shape Circle
@trait Round <: Shape
struct Disk; r::Float64; end
area(d::Disk) = 3.0 * d.r^2
@implement Round Disk
@trait Col{T} begin
    T = eltype(Self)
end
struct IntCol; v::Vector{Int}; end
Base.eltype(::Type{IntCol}) = Int
@implement Col{Int} IntCol

inv = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
Base.convert(::Type{T}, d::Dynamic{<:T}) where {T} = unwrap(d)
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
cis = count(x -> x isa Core.CodeInstance, inv)
println("the definition's invalidation log: ", length(inv), " entries, ", cis, " code instances")

v = Shape[]
push!(v, Dynamic{Shape}(Circle(1.0)))
push!(v, Circle(2.0))
push!(v, Dynamic{Round}(Disk(1.0)))            # a subtrait's box into the trait's storage
println("Vector{Shape} holds: ", typeof.(v))
c = Col[]; push!(c, Dynamic{Col{Int}}(IntCol([1])))
ci = Col{Int}[]; push!(ci, Dynamic{Col{Int}}(IntCol([1])))
println("Vector{Col} holds: ", typeof.(c), "; Vector{Col{Int}}: ", typeof.(ci))
d = Dynamic{Shape}[]; push!(d, Dynamic{Shape}(Circle(1.0)))
println("Vector{Dynamic{Shape}} holds: ", typeof.(d))
a = Any[]; push!(a, Dynamic{Shape}(Circle(1.0)))
println("Vector{Any} holds: ", typeof.(a))
mutable struct Scene; s::Shape; end
sc = Scene(Dynamic{Shape}(Circle(1.0)))
println("a field ::Shape holds: ", typeof(sc.s))
f()::Shape = Dynamic{Shape}(Circle(1.0))
println("a result declared ::Shape: ", typeof(f()))

