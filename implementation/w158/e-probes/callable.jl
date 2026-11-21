# W-158, third part (E-510): a function known only by its signature in a closed build (compiler §7.4, §7.6; C-154,
# C-151, C-152). The build's check run in the session (`closed_check`), per case: errors, rounds, each split's members,
# each error's statement. `PATCH=1` lays the worktree's compiler change over the session's first (`patch_e.jl`).
# Run from the library's project: `$J --project=. $W158/e-probes/callable.jl [case ...]`.
get(ENV, "PATCH", "0") == "1" && include(joinpath(@__DIR__, "patch_e.jl"))
using TraitWorld
const CC = Base.Compiler

# 1. the call of the object a box of an intersection of two signatures holds (the library's box call method,
#    `src/callable.jl`): each signature's call branches over the intersection's members
const G2 = All{Callable{Tuple{Float64}, Float64}, Callable{Tuple{Int}, Float64}}
hh(x::Float64) = 2x
hh(x::Int) = 3.0 * x
kk(x::Float64) = x + 1
kk(x::Int) = Float64(x)
boxall(n::Int) = (s = 0.0; for d in Dynamic{G2}[Dynamic{G2}(hh), Dynamic{G2}(kk)]; s += d(1.0) + d(n); end; s)
# a box of one signature, called as itself
const G1 = Callable{Tuple{Float64}, Float64}
boxone(n::Int) = (s = 0.0; for d in Dynamic{G1}[Dynamic{G1}(hh), Dynamic{G1}(kk)]; s += d(Float64(n)); end; s)
# a function known only as `Callable{A, S}`, no kept form: an argument declared `@nospecialize` (compiler §6.2)
@noinline callns(@nospecialize(f::Callable{Tuple{Float64}, Float64}), x::Float64) = f(x)
nospec(n::Int) = callns(hh, Float64(n)) + callns(kk, 1.0)

# 2. a constructor that takes two values known only by `Callable` signatures (the ODE port's callbacks): the method at
#    the signatures erases by default, its forwarder boxes each function and tests `hasmethod(f, A)`
struct Pair2{C<:Callable{Tuple{Float64}, Float64}, A<:Callable{Tuple{Int}, Float64}}
    c::C
    a::A
end
mkpair(c::Callable{Tuple{Float64}, Float64}, a::Callable{Tuple{Int}, Float64}) = Pair2{typeof(c), typeof(a)}(c, a)
struct Raw2
    c::Callable                       # kept without a signature, as the port's `DiscreteCallback`
    a::Callable
end
usepair(p::Pair2) = p.c(1.0) + p.a(2)
enter2(rs::Vector{Raw2}) = (s = 0.0; for r in rs; s += usepair(mkpair(r.c, r.a)); end; s)
ctor2(n::Int) = enter2([Raw2(hh, kk), Raw2(kk, hh)]) + n
# one such argument: the forwarder of `keep1` at the signature, called with a value known only by bare `Callable`
keep1(c::Callable{Tuple{Float64}, Float64}) = Pair2{typeof(c), typeof(kk)}(c, kk)
@noinline enter1(rs::Vector{Raw2}) = (s = 0.0; for r in rs; s += usepair(keep1(r.c)); end; s)
ctor1(n::Int) = enter1([Raw2(isodd(n) ? hh : kk, kk)]) + n

# 3. two arguments where the member's type chooses the method (compiler §7.6, "With several such arguments")
@trait ShapeE begin
    areaE(s::ShapeE)::Float64
end
struct SqE; a::Float64; end
struct CiE; r::Float64; end
areaE(s::SqE) = s.a^2
areaE(c::CiE) = 3.0 * c.r^2
@implement ShapeE SqE
@implement ShapeE CiE
pairup(@nospecialize(x), @nospecialize(y)) = 0
pairup(x::SqE, y::CiE) = 1
pairup(x::CiE, y::SqE) = 2
pairup(x::CiE, y::CiE) = 3
twochoice(n::Int) = (v = ShapeE[SqE(Float64(n)), CiE(1.0)]; s = 0; for a in v, b in v; s += pairup(a, b); end; s)

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
        w && continue
        for fr in first(CC.TrimVerifier.verify_create_stackframes(e.codeinst, e.stmtidx, res[2]), 4)
            println("      at ", fr)
        end
    end
    return res
end
const CASES = Dict("boxall" => boxall, "boxone" => boxone, "nospec" => nospec, "ctor2" => ctor2, "ctor1" => ctor1, "twochoice" => twochoice)
for name in (isempty(ARGS) ? ["boxall", "boxone", "nospec", "ctor2", "ctor1", "twochoice"] : ARGS)
    f = CASES[name]
    check(f, (Int,))
    println("  session: ", f(2))
end
