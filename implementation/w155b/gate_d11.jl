# E-456 (W-155b, D-11): a membership adds no type equality inside an invariant parameter
# (compiler §4.5, §4.9; C-104; GT-18). W-152's `p7b/case.jl` (E-400) as a gate: a `Vector{Union{X, S}}`
# made before `S` joins `X`; `isa`, `<:`, `==`, `typeintersect` and dispatch at `Vector{X}` and at
# `AbstractVector{X}`, fresh and in code compiled before the membership, agree, and say "two types";
# `Vector{<:X}` takes both types once `S` joins (a variable's bound is a subtype question).
#     julia --project=env_lib gate_d11.jl
using TraitWorld
@trait X begin
    op(x::X)::Int
end
struct A end; op(::A) = 1
@implement X A
struct S end; op(::S) = 2
h(v::Vector{X}) = :vecX
h(v) = :untyped
k(v) = h(v)
h2(v::AbstractVector{X}) = :absX
h2(v) = :untyped
k2(v) = h2(v)
h3(v::Vector{<:X}) = :vecsubX
h3(v) = :untyped
k3(v) = h3(v)
isit(v) = v isa AbstractVector{X}
isvec(v) = v isa Vector{X}
issub(v) = v isa Vector{<:X}
const T = Vector{Union{X, S}}
v = T(); vs = Vector{S}()
# compiled before the membership
before = (k(v), k2(v), isit(v), isvec(v), issub(v), k3(vs), issub(vs))
@implement X S
fails = String[]
check(name, got, want) = (ok = isequal(got, want); println(rpad(name, 64), got, ok ? "" : "   <-- want $want"); ok || push!(fails, name))
println("compiled before the membership: ", before)
# the unions inside a parameter: two types in every world
check("S <: X (the membership)", S <: X, true)
check("T <: Vector{X}", T <: Vector{X}, false)
check("Vector{X} <: T", Vector{X} <: T, false)
check("T == Vector{X}", T == Vector{X}, false)
check("v isa Vector{X}", v isa Vector{X}, false)
check("isvec(v), compiled before", isvec(v), false)
check("isvec(v), compiled after", Base.invokelatest(v -> v isa Vector{X}, v), false)
check("T <: AbstractVector{X}", T <: AbstractVector{X}, false)
check("v isa AbstractVector{X}", v isa AbstractVector{X}, false)
check("isit(v), compiled before", isit(v), false)
check("typeintersect(T, Vector{X})", typeintersect(T, Vector{X}), Union{})
check("typeintersect(T, AbstractVector{X})", typeintersect(T, AbstractVector{X}), Union{})
check("h(v), a method at Vector{X}", h(v), :untyped)
check("k(v), a caller compiled before", k(v), :untyped)
check("which(h, (T,)) is the untyped method", which(h, (T,)).sig, Tuple{typeof(h), Any})
check("a caller compiled after", Base.invokelatest((g = v -> h(v); g), v), :untyped)
check("h2(v), a method at AbstractVector{X}", h2(v), :untyped)
check("k2(v), compiled before", k2(v), :untyped)
# a variable's bound is a subtype question: Vector{<:X} takes both, once S joins
check("T <: Vector{<:X}", T <: Vector{<:X}, true)
check("v isa Vector{<:X}", v isa Vector{<:X}, true)
check("issub(v), compiled before", issub(v), true)
check("Vector{S} <: Vector{<:X}", Vector{S} <: Vector{<:X}, true)
check("issub(vs), compiled before", issub(vs), true)
check("h3(v), a method at Vector{<:X}", h3(v), :vecsubX)
check("k3(vs), compiled before", k3(vs), :vecsubX)
check("typeintersect(Vector{S}, Vector{<:X})", typeintersect(Vector{S}, Vector{<:X}), Vector{S})
check("typeintersect(T, Vector{<:X})", typeintersect(T, Vector{<:X}), T)
# nested: a tuple inside an invariant parameter is compared by its declared structure too
check("Vector{Tuple{S}} <: Vector{Tuple{X}}", Vector{Tuple{S}} <: Vector{Tuple{X}}, false)
check("Vector{Tuple{S}} <: Vector{<:Tuple{X}}", Vector{Tuple{S}} <: Vector{<:Tuple{X}}, true)
check("Tuple{S} <: Tuple{X} (covariant)", Tuple{S} <: Tuple{X}, true)
check("Union{X, S} == X at the top level (subtype both ways)", Union{X, S} == X, true)
# the type expression after the membership is the same type object
check("Vector{Union{X, S}} written again === T", Vector{Union{X, S}} === T, true)
println(isempty(fails) ? "gate_d11: OK ($(length(fails)) failed)" : "gate_d11: FAIL $(length(fails)): " * join(fails, "; "))
