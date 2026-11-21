# W-158, second part: members by the types that flow to a set instance (compiler §7.6, C-152), the kept
# form by use, no member (C-102); the build's check run in the session. `PATCH=1` lays the worktree's
# change over the session's compiler first (`patch_c.jl`). Run from the library's project.
get(ENV, "PATCH", "0") == "1" && include(joinpath(@__DIR__, "patch_c.jl"))
using TraitWorld
const CC = Base.Compiler

const F1 = Callable{Tuple{Float64}, Float64}
const F2 = Callable{Tuple{Int}, Int}
# (the call of the object a box of `Callable` holds is left to dispatch: each signature's split is the
# wrapper's constructor, `compiled_for(f)`, which branches over the signature's members)
sig1(f::Callable{Tuple{Float64}, Float64}, x::Float64) = compiled_for(f)(x)
sig2(f::Callable{Tuple{Int}, Int}, x::Int) = compiled_for(f)(x)
double(x::Float64) = 2x
inc(x::Int) = x + 1
triple(x::Int) = 3x
quad(x::Float64) = 4x
struct Holder; f::Function; end
@noinline keep(h::Holder) = h
struct Wrap{F}; f::F; end
(w::Wrap)(x::Int) = round(Int, w.f(Float64(x)))
@implement Callable Wrap{F} where {F}
# a place typed by F2 (`Vector{F2}`) that holds `Wrap(f)` for each member `f` at F1: `Wrap{M}` is a member at
# F2, not at F1, so the rounds do not feed `Wrap` its own instances
function handon(d::Dynamic{Callable{Tuple{Float64}, Float64}})
    ws = Callable{Tuple{Int}, Int}[]
    push!(ws, Wrap(unwrap(d)))
    return sig2(ws[1], 3) + sig1(d, 1.0)
end
@noinline anyhand(v::Vector{Any}) = (x = v[1]; x isa Callable{Tuple{Float64}, Float64} ? sig1(x, 1.0) : 0.0)

two(n::Int) = sig1(double, Float64(n)) + sig2(inc, n) + keep(Holder(triple)).f(1)
passed(n::Int) = sig1(double, Float64(n)) + sig2(keep(Holder(triple)).f, n)
wrapped(n::Int) = handon(Dynamic{F1}(double)) + sig2(inc, n)
viaany(n::Int) = anyhand(Any[quad]) + sig1(double, Float64(n))

# the kept form by use: a box stored in a `Vector{Shape7}` is a member at `Shape7`; the split at the object a
# box holds has none (the box's forwarding method)
@trait Shape7 begin
    area7(s::Shape7)::Float64
end
struct Sq7; a::Float64; end
struct Ci7; r::Float64; end
area7(s::Sq7) = s.a^2
area7(c::Ci7) = 3.0 * c.r^2
@implement Shape7 Sq7
@implement Shape7 Ci7
boxes(n::Int) = (v = Shape7[Dynamic{Shape7}(Sq7(Float64(n))), Ci7(1.0)]; s = 0.0; for x in v; s += area7(x); end; s)
noboxes(n::Int) = (v = Shape7[Sq7(Float64(n)), Ci7(1.0)]; s = 0.0; for x in v; s += area7(x); end; s)
# no member: an operation of a trait whose one entry is a family the program never uses
@trait Lonely begin
    lone(x::Lonely)::Int
end
struct LoF{T}; end
lone(::LoF) = 1
@implement Lonely LoF{T} where {T}
lonely(v::Vector{Lonely}) = isempty(v) ? 0 : lone(v[1])

function check(f, args)
    mi = CC.specialize_method(Base._methods_by_ftype(Base.signature_type(f, args), 1, Base.get_world_counter())[1])
    t = @elapsed res = CC.closed_check(Any[mi], Base.get_world_counter(), TraitWorld._build_base())
    errs = res[1]
    nerr = count(e -> !e[1], errs)
    println(f, ": ", nerr, " errors, ", length(res) >= 4 ? res[4] : "?", " rounds, ", round(t; digits = 2), " s")
    length(res) >= 3 && for (X, ms) in res[3]
        println("  ", X, ": ", join(string.(ms), ", "))
    end
    for (w, e) in errs
        println(w ? "  raises: " : "  error: ", e.desc, " | ", sprint(io -> CC.TrimVerifier.verify_print_stmt(io, e.codeinfo, e.sptypes, e.stmtidx)))
    end
    return res
end
for (f, a) in ((two, (Int,)), (passed, (Int,)), (wrapped, (Int,)), (viaany, (Int,)), (boxes, (Int,)),
               (noboxes, (Int,)), (lonely, (Vector{Lonely},)))
    check(f, a)
end
println(two(2), " ", passed(2), " ", wrapped(2), " ", viaany(2), " ", boxes(2), " ", noboxes(2), " ",
        lonely(Lonely[]), " ", lonely(Lonely[LoF{Int}()]))
