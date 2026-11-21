# W-158, third part (item 5): a verifier-clean closed build whose code invokes a code instance the build did not
# compile. An operation's call at a set in `render` (noted: inferred again when a later round adds a member); its
# caller calls it with a constant, so the caller invokes the code inferred with that constant, a code instance of its
# own. Round 2 adds a member (`Fam{Int}`, forgotten in `main`'s vector), ends `render`'s code and infers it again.
# With the rounds of 61277571fa (OLD=1: a caller found only by an invoke of a stale code instance) `main` is kept, and
# invokes round 1's code, which the last round does not compile; the verifier of 8b35e4b77c takes the invoke as
# resolved (the instance has other code); the verifier of this change refuses it. `PATCH=1` lays the change over.
# (OLD=1 does not reproduce it here: the caller's invoke names the stale code itself; OLD=2 models a caller missed.)
# Run from the library's project: $J --project=. stale_invoke.jl
get(ENV, "PATCH", "0") == "1" && include(joinpath(@__DIR__, "patch_e.jl"))
get(ENV, "OLD", "0") == "1" && include(joinpath(@__DIR__, "old_invalidate.jl"))
# OLD=2: a caller the rounds miss, at its plainest: no caller is inferred again
get(ENV, "OLD", "0") == "2" && Core.eval(Base.Compiler, :(closed_invalidate_callers!(codeinfos::Vector{Any}, stale::IdSet{Any}, world::UInt, owner = nothing) = nothing))
using TraitWorld
const CC = Base.Compiler
@trait ShS begin
    arS(s::ShS)::Float64
end
struct A1; end
struct Fam{T}; t::T; end
arS(::A1) = 1.0
arS(f::Fam) = 2.0
@implement ShS A1
@implement ShS Fam{T} where {T}
# (with the constant, a narrower result than without: the caller takes the code inferred with it)
Base.@constprop :aggressive @noinline render(v::Vector{ShS}, k::Float64) =
    (s = 0.0; for x in v; s += arS(x); end; k == 1.0 ? s : k == 2.0 ? nothing : Int(round(s * k)))
stale_main(n::Int) = render(ShS[A1(), Fam(n)], 1.0)::Float64
w = Base.get_world_counter()
mi = CC.specialize_method(only(Base._methods_by_ftype(Tuple{typeof(stale_main), Int}, 1, w)))
errors, parents, members, rounds = CC.closed_check(Any[mi], w, TraitWorld._build_base())
println("stale_main: ", count(e -> !e[1], errors), " errors, ", rounds, " rounds; members ", members)
for (warn, e) in errors
    warn && continue
    println("  error: ", e.desc, " | ", sprint(io -> CC.TrimVerifier.verify_print_stmt(io, e.codeinfo, e.sptypes, e.stmtidx)))
end
println("session: ", stale_main(2))
