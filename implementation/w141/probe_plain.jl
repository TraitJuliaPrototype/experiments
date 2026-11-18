# E-367, stage 0 (W-141): the method table's side of "a membership is a method", on plain functions.
# R1: one function with thousands of methods (::Type{X}, ::Type{<:S}). R2: a trait's inputs under Type{…}.
# R3: which signature a negative's edge carries. Run: julia --startup-file=no probe_plain.jl
function impl end
const N = 5000
abstract type X0 end
# R1a: N members of one trait
t_def = @elapsed for i in 1:N
    @eval struct $(Symbol(:S, i)) end
    @eval impl(::Type{X0}, ::Type{<:$(Symbol(:S, i))}) = nothing
end
println("R1a: $N structs and methods at one trait: ", round(t_def / N * 1e6; digits = 1), " us each (struct + method)")
t_only = @elapsed for i in 1:N
    @eval struct $(Symbol(:R, i)) end
end
println("R1a: the structs alone: ", round(t_only / N * 1e6; digits = 1), " us each")
# R1b: N traits, one member each
t_def2 = @elapsed for i in 1:N
    @eval abstract type $(Symbol(:Y, i)) end
    @eval impl(::Type{$(Symbol(:Y, i))}, ::Type{<:$(Symbol(:R, i))}) = nothing
end
println("R1b: $N traits with one member: ", round(t_def2 / N * 1e6; digits = 1), " us each (type + method)")
println("R1: methods(impl): ", length(methods(impl)), " in ", round(1e3 * @elapsed(methods(impl)); digits = 1), " ms")
w = Base.get_world_counter()
look(sig) = Base._methods_by_ftype(sig, -1, w)
look(Tuple{typeof(impl), Type{X0}, Type{S17}})
t_hit = @elapsed for i in 1:1000; look(Tuple{typeof(impl), Type{X0}, Type{S17}}); end
t_miss = @elapsed for i in 1:1000; look(Tuple{typeof(impl), Type{X0}, Type{Int}}); end
println("R1: a lookup that hits: ", round(t_hit * 1e3; digits = 2), " us; that misses: ", round(t_miss * 1e3; digits = 2), " us")
t_last = @elapsed (@eval struct Late end; @eval impl(::Type{X0}, ::Type{<:Late}) = nothing)
println("R1: method ", 2N + 1, ": ", round(t_last * 1e3; digits = 2), " ms")

# R2: inputs
abstract type Indexable{T} end
impl(::Type{Indexable{T}}, ::Type{<:Vector{T}}) where {T} = nothing
impl(::Type{Indexable{Char}}, ::Type{<:String}) = nothing
m = look(Tuple{typeof(impl), Type{<:Indexable}, Type{Vector{Int}}})
println("R2: the instance for Vector{Int}: ", length(m) == 1 ? m[1].sparams : m)
m = look(Tuple{typeof(impl), Type{<:Indexable}, Type{String}})
println("R2: the instance for String: ", length(m), " match, sig ", length(m) == 1 ? m[1].method.sig : nothing)
println("R2: Vector{Int} at Indexable{Int}: ", hasmethod(impl, Tuple{Type{Indexable{Int}}, Type{Vector{Int}}}),
        "; at Indexable{Float64}: ", hasmethod(impl, Tuple{Type{Indexable{Float64}}, Type{Vector{Int}}}))
# a member pattern with a bound, and the bare trait asked
abstract type Column{T} end
impl(::Type{Column{T}}, ::Type{<:AbstractVector{T}}) where {T <: Number} = nothing
println("R2: Vector{Float64} <: Column: ", !isempty(look(Tuple{typeof(impl), Type{<:Column}, Type{Vector{Float64}}})),
        "; Vector{String}: ", !isempty(look(Tuple{typeof(impl), Type{<:Column}, Type{Vector{String}}})))
# two methods at one type with different instances
impl(::Type{Indexable{Int}}, ::Type{<:Vector{Int}}) = nothing      # same instance: more specific, no conflict
m = look(Tuple{typeof(impl), Type{<:Indexable}, Type{Vector{Int}}})
println("R2: two methods at Vector{Int}: ", length(m), " matches")

# R3: the signature of a negative's edge
abstract type A2 end
struct A3 <: A2 end
neg_exact = Tuple{typeof(impl), Type{X0}, Type{A2}}          # "A2 <: X0" is false
neg_meet  = Tuple{typeof(impl), Type{X0}, Type{<:A2}}        # "no type is in A2 and X0"
newm = Tuple{typeof(impl), Type{X0}, Type{<:A3}}             # A3 joins X0
println("R3: A3's membership meets the exact pair's edge: ", typeintersect(neg_exact, newm) !== Union{},
        "; the unmet intersection's edge: ", typeintersect(neg_meet, newm) !== Union{})
