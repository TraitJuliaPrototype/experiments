# Gate (W-114; compiler §2.7; traits §14): fully typed mode is the compiler's. A method that asks for it,
# by its meta or its module's option, is compiled by facts. Where its code at a signature has a call
# dispatched when it runs, in it or in a callee, or a result of an abstract type that is not a set,
# the code starts with a check that reaches the library's hook: it warns once (warn) or raises at every
# run (enforce). Fully typed code has no check, and its effects are its own.
include("util.jl")
const CC = Base.Compiler

# the hook a library sets: record the sites, and raise under enforce
const SEEN = Any[]
struct NotFT <: Exception
    kind::Int
end
hook(site::Core.SimpleVector) = (push!(SEEN, (site[1].specTypes, site[2], site[4], site[5]));
                                 site[2] == 2 && throw(NotFT(site[4])); nothing)
ccall(:jl_set_fully_typed_hook, Cvoid, (Any,), hook)

# the code compiled by facts at T (what runs: the mode compiles the method by facts)
checked(f, T) = any(st -> Meta.isexpr(st, :foreigncall) && st.args[1] == Expr(:tuple, QuoteNode(:jl_not_fully_typed)),
                    Base.code_typed(f, T; interp = CC.NativeInterpreter(; facts = true))[1][1].code)
policy(f) = ccall(:jl_method_policy, Cint, (Any,), only(methods(f)))

sink(a) = a
struct Box1; a::Any; end

# (1) per method, by its meta: enforce
eval(Base.pushmeta!(:(bad(v::Vector{Any}) = sink(v[1])), :fully_typed_enforce))
eval(Base.pushmeta!(:(good(v::Vector{Int}) = v[1] + 1), :fully_typed_enforce))
eval(Base.pushmeta!(:(absres(b::Box1) = b.a), :fully_typed_enforce))
@assert policy(bad) == 1 && policy(good) == 1 "fully typed mode compiles the method by facts"
@assert checked(bad, (Vector{Any},)) "a run-time site: the code starts with the check"
@assert !checked(good, (Vector{Int},)) "fully typed code has no check"
@assert checked(absres, (Box1,)) "an abstract result: the check"
@assert good([1]) == 2
@assert try bad(Any[1]); false catch e; e isa NotFT && e.kind == 1 end
@assert try bad(Any[1]); false catch e; e isa NotFT end "enforce raises at every run"
@assert try absres(Box1(1)); false catch e; e isa NotFT && e.kind == 2 end
@assert !CC.is_foldable(Base.infer_effects(bad, (Vector{Any},))) "the check is never folded"

# (2) a callee's run-time site counts: the caller is not fully typed
inner(v::Vector{Any}) = sink(v[1])          # plain, not in the mode
eval(Base.pushmeta!(:(outer(v::Vector{Any}) = inner(v)), :fully_typed_enforce))
eval(Base.pushmeta!(:(outer2(v::Vector{Int}) = inner2(v)), :fully_typed_enforce))
inner2(v::Vector{Int}) = v[1]
@assert try outer(Any[1]); false catch e; e isa NotFT end "a run-time site in facts code it calls"
@assert outer2([3]) == 3 && !checked(outer2, (Vector{Int},))

# (3) warn: the hook once per signature, and the code runs
empty!(SEEN)
eval(Base.pushmeta!(:(wbad(v::Vector{Any}) = sink(v[1])), :fully_typed_warn))
for _ in 1:5
    @assert wbad(Any[7]) == 7
end
@assert length(SEEN) == 1 && SEEN[1][1] == Tuple{typeof(wbad), Vector{Any}} && SEEN[1][2] == 1 "warned once: $SEEN"

# (4) per module, by its option; a result typed by a set is declared
module FT
Base.Experimental.@compiler_options fully_typed=enforce
import ..sink, ..Box1
abstract type Shape end                     # a plain abstract type: not a set
mbad(v::Vector{Any}) = sink(v[1])
mgood(x::Int) = x + 1
mabs(b::Box1) = b.a
end
@assert ccall(:jl_method_fully_typed, Cint, (Any,), only(methods(FT.mbad))) == 2
@assert FT.mgood(1) == 2 && !checked(FT.mgood, (Int,))
@assert try FT.mbad(Any[1]); false catch e; e isa NotFT end
@assert try FT.mabs(Box1(1)); false catch e; e isa NotFT && e.kind == 2 end

# (5) without a hook, enforce raises Julia's error
ccall(:jl_set_fully_typed_hook, Cvoid, (Any,), nothing)
eval(Base.pushmeta!(:(bad3(v::Vector{Any}) = sink(v[1])), :fully_typed_enforce))
@assert try bad3(Any[1]); false catch e; e isa ErrorException && occursin("fully typed", e.msg) end

println("n9_fully_typed: OK")
