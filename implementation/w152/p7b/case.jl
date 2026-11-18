# E-400 (W-152; the review of 2026-11-15, P7 (b)): GT-18's case on the head (compiler C-88 (e)).
# A `Vector{Union{X, S}}` made before `S` joins `X`; a method at `Vector{X}`; the call before and after.
#     julia --project=../../w134/env_lib case.jl
using TraitWorld
@trait X begin
    op(x::X)::Int
end
struct A end; op(::A) = 1
@implement X A
struct S end; op(::S) = 2
h(v::Vector{X}) = "the method at Vector{X}"
h(v) = "the untyped method"
k(v) = h(v)                       # a compiled caller
h2(v::AbstractVector{X}) = "the method at AbstractVector{X}"
h2(v) = "the untyped method"
k2(v) = h2(v)
isit(v) = v isa AbstractVector{X}
const T = Vector{Union{X, S}}
v = T()
println("before the membership: v isa Vector{X}: ", v isa Vector{X}, " | T == Vector{X}: ", T == Vector{X}, " | T === Vector{X}: ", T === Vector{X})
println("   h(v): ", h(v), " | k(v): ", k(v))
println("   at an abstract type: v isa AbstractVector{X}: ", v isa AbstractVector{X}, " (compiled: ", isit(v), ") | h2(v): ", h2(v), " | k2(v): ", k2(v))
@implement X S
println("after the membership:  v isa Vector{X}: ", v isa Vector{X}, " | T == Vector{X}: ", T == Vector{X}, " | T === Vector{X}: ", T === Vector{X}, " | T <: Vector{X}: ", T <: Vector{X}, " | Vector{X} <: T: ", Vector{X} <: T)
println("   h(v): ", h(v), " | k(v): ", k(v), " | which: ", which(h, (T,)).sig, " | a call compiled now: ", Base.invokelatest(() -> h(v)))
w = Vector{Union{X, S}}()         # the same type expression after the membership
println("   the type written again: ", typeof(w) === T, " | h(w): ", h(w))
g(v) = h(v); println("   a caller compiled after: ", g(v))
println("   at an abstract type: v isa AbstractVector{X}: ", v isa AbstractVector{X}, " (compiled before: ", isit(v), ") | T <: AbstractVector{X}: ", T <: AbstractVector{X})
println("   h2(v): ", h2(v), " | k2(v), compiled before: ", k2(v), " | which: ", which(h2, (T,)).sig, " | a caller compiled after: ", (g2(v) = h2(v); Base.invokelatest(g2, v)))
