# Gate (W-141, E-367): a membership is a method of `Core.implements`.
# (1) A declaration has its method, in the declarer's module, from the entry's world.
# (2) A method defined by a program declares the membership: a type, a family, an abstract type, a
#     forwarding field. Running code sees it after it returns to the top level, as a method.
# (3) The one spelling: `::Type{S}` for a concrete member, `::Type{<:S}` for an abstract one.
# (4) A folded negative holds an edge at the pair's signature and is ended by the method; a folded
#     positive holds an edge to the method's instance.
# (5) A subtrait's member is found from the trait's signature; two memberships that apply are no error.
# (6) A membership's method is not deleted.
# (7) In a package image: the method is kept, and the membership holds after the load.
using Traits
include("util.jl")
latest(f, T) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                               c.def.specTypes === Tuple{typeof(f), T}])
impl(X, S) = methods(Core.implements, Tuple{Type{X}, Type{S}})

@trait Shape
@trait Col{T}
@trait Wide
struct Circle end
struct Sq end
struct Vec{T}; v::Vector{T}; end
abstract type Poly end
struct Tri <: Poly end
struct Wrap; inner::Circle; end
struct Other end

# (1) the declaration's method
e = @implement Shape Circle
m = only(impl(Shape, Circle))
@assert e.method === m && m.module === Main && m.primary_world == e.min_world "the method of the entry: $m"
@assert m.sig === Tuple{typeof(Core.implements), Type{Shape}, Type{Circle}}

# (2) a method defined by a program
isshape(x) = x isa Shape
@assert isshape(Sq()) === false
ci_neg = latest(isshape, Sq)
function declare_inside()
    @eval Core.implements(::Type{Shape}, ::Type{Sq}) = nothing
    return Sq <: Shape                       # the caller's world: not yet
end
@assert declare_inside() === false "a membership begins in a new world, as a method"
@assert Sq <: Shape && isshape(Sq()) === true
@assert ci_neg.max_world < typemax(UInt) "the method ended the code that relied on the pair's absence"
ent(S, X) = collect(ccall(:jl_membership_entries_for, Any, (Any, Any, UInt), S, X, Base.get_world_counter()))
@assert any(en -> en.method === only(impl(Shape, Sq)) && en.receiver === :self, ent(Sq, Shape))
# a family, with the trait's input
Core.implements(::Type{Col{T}}, ::Type{Vec{T}}) where {T} = nothing
@assert Vec{Int} <: Col{Int} && !(Vec{Int} <: Col{Float64}) && Vec{String} <: Col
# an abstract type: every type under it
Core.implements(::Type{Shape}, ::Type{<:Poly}) = nothing
@assert Tri <: Shape && Poly <: Shape
# a forwarding field
Core.implements(::Type{Shape}, ::Type{Wrap}) = :inner
@assert Wrap <: Shape && any(en -> en.receiver === :field && en.by === :inner, ent(Wrap, Shape))

# (3) the one spelling
refused(ex) = try Core.eval(Main, ex); false catch err; err isa ErrorException end
@assert refused(:(Core.implements(::Type{Wide}, ::Type{<:Other}) = nothing)) "a concrete member as Type{<:S}"
@assert refused(:(Core.implements(::Type{Wide}, ::Type{Poly}) = nothing)) "an abstract member as Type{S}"
@assert refused(:(Core.implements(::Type{Wide}, ::Type{Other}) = 1)) "a body that is no receiver"
@assert refused(:(Core.implements(::Type{Int}, ::Type{Other}) = nothing)) "a type that is no trait"
@assert !(Other <: Wide) && isempty(impl(Wide, Other))

# (4) the edges
@assert length(absences(ci_neg)) == 1 && absence_member(only(absences(ci_neg))) === Sq
iscirc(x) = x isa Shape
@assert iscirc(Circle()) === true
ci_pos = latest(iscirc, Circle)
pos = [ci_pos.edges[i+1] for i in 1:length(ci_pos.edges)-1 if ci_pos.edges[i+1] isa Core.MethodInstance && ci_pos.edges[i+1].def === m]
@assert length(pos) == 1 "a folded positive holds the method's instance: $(ci_pos.edges)"
@assert ci_pos.min_world >= m.primary_world

# (5) a subtrait's member; two memberships that apply
@trait Round <: Shape
struct Disk end
isround(x) = x isa Shape
@assert isround(Disk()) === false
ci_d = latest(isround, Disk)
@implement Round Disk
@assert isround(Disk()) === true && ci_d.max_world < typemax(UInt) "a membership in a subtrait ends the trait's negative"
@implement Shape Disk                         # a second way to be a Shape: no error
@assert Disk <: Shape && Disk <: Round

# (6) no deletion
@assert try Base.delete_method(m); false catch err; err isa ErrorException end
@assert Circle <: Shape

# (7) a package image
const ROOT = mktempdir()
const PKGS = joinpath(ROOT, "pkgs"); const DEPOT = joinpath(ROOT, "depot"); mkpath(DEPOT)
pkg(name, body) = (mkpath(joinpath(PKGS, name, "src")); write(joinpath(PKGS, name, "src", "$name.jl"), body))
pkg("MA", """
module MA
using Traits
@trait X
struct S end
struct T end
Core.implements(::Type{X}, ::Type{S}) = nothing
f(x) = :any
f(x::X) = :set
h(s) = f(s)
precompile(h, (S,)); precompile(h, (T,))
end
""")
pkg("MB", """
module MB
using MA
Core.implements(::Type{MA.X}, ::Type{MA.T}) = nothing
end
""")
const UNIF = dirname(@__DIR__)
function child(code)
    env = copy(ENV)
    env["JULIA_DEPOT_PATH"] = DEPOT * ":" * join(DEPOT_PATH[2:end], ":")
    env["JULIA_LOAD_PATH"] = join([PKGS, UNIF, "@stdlib"], ":")
    out = IOBuffer(); err = IOBuffer()
    ok = success(pipeline(setenv(`$(Base.julia_cmd()) --startup-file=no -e $code`, env); stdout = out, stderr = err))
    return ok, String(take!(out)), String(take!(err))
end
for p in ("MA", "MB")
    local ok, out, err = child("using $p")
    @assert ok "precompiling $p: $err"
end
let (ok, out, err) = child("""
    using MA
    println("a ", MA.S <: MA.X, " ", MA.T <: MA.X, " ", MA.h(MA.S()), " ", MA.h(MA.T()), " ",
            only(methods(Core.implements, Tuple{Type{MA.X}, Type{MA.S}})).module)
    using MB
    println("b ", MA.T <: MA.X, " ", MA.h(MA.T()))
""")
    @assert ok "the image: $err"
    @assert occursin("a true false set any MA", out) "the image's membership: $out"
    @assert occursin("b true set", out) "a later image's membership ends the image's code: $out"
end
rm(ROOT; recursive = true, force = true)
println("n29_membership_method: OK")
