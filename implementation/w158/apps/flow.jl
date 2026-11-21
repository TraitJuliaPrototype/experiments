# W-158, second part (E-510): a trimmed program for the members by flow and the kept form by use (compiler §7.6).
# - two `Callable` signatures, a function handed to each; a function kept in a field `f::Function` and handed on at
#   the second; `Wrap(f)` of the first signature's member handed on at the second, through a `Vector` typed by it;
# - a box stored in a `Vector{Shape}` with a plain member, an operation called on each element: the box is a member
#   at `Shape` by use, and the box's forwarding method splits at the object it holds with no box branch;
# - an operation of a trait with no member in the program: the call raises `MethodError`.
# `julia --project=<TraitWorld> apps/flow.jl` runs `main` in a session.
using TraitWorld
const F1 = Callable{Tuple{Float64}, Float64}
const F2 = Callable{Tuple{Int}, Int}
sig1(f::Callable{Tuple{Float64}, Float64}, x::Float64) = compiled_for(f)(x)
sig2(f::Callable{Tuple{Int}, Int}, x::Int) = compiled_for(f)(x)
double(x::Float64) = 2x
inc(x::Int) = x + 1
triple(x::Int) = 3x
struct Holder; f::Function; end
@noinline keep(h::Holder) = h
struct Wrap{F}; f::F; end
(w::Wrap)(x::Int) = round(Int, w.f(Float64(x)))
@implement Callable Wrap{F} where {F}
function handon(d::Dynamic{Callable{Tuple{Float64}, Float64}})
    ws = Callable{Tuple{Int}, Int}[]
    push!(ws, Wrap(unwrap(d)))
    return sig2(ws[1], 3) + sig1(d, 1.0)
end
@trait Shape begin
    area(s::Shape)::Float64
end
struct Square; a::Float64; end
struct Circle; r::Float64; end
area(s::Square) = s.a^2
area(c::Circle) = 3.0 * c.r^2
@implement Shape Square
@implement Shape Circle
@trait Lonely begin
    lone(x::Lonely)::Int
end
struct LoF{T}; end
lone(::LoF) = 1
@implement Lonely LoF{T} where {T}
@noinline lonely(v::Vector{Lonely}) = isempty(v) ? 0 : lone(v[1])
function (@main)(args::Vector{String})::Cint
    n = length(args) + 2
    println(Core.stdout, "signatures ", sig1(double, Float64(n)), " ", sig2(inc, n), " ", sig2(keep(Holder(triple)).f, n))
    println(Core.stdout, "handed on ", handon(Dynamic{F1}(double)))
    v = Shape[Dynamic{Shape}(Square(Float64(n))), Circle(1.0)]
    s = 0.0
    for x in v
        s += area(x)
    end
    println(Core.stdout, "areas ", s)
    println(Core.stdout, "no member ", lonely(Lonely[]))
    return 0
end
