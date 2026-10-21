# Warnings that teach (the review's example 4 and §2.6 item 4; the user's criterion: "badly written
# code may run slower if the compiler says how to make it fast"). Concrete mode
# (`@warn_not_fully_typed`) on six common ways of writing slow Julia, each beside its fixed twin.
# What is the user told: is there a warning, does it name the line, the root cause, and the fix?
#
#     julia --project=../env teach.jl        (SHOW=1 prints every warning)
#
# Expected (design.md §3.4, §4.3, decided certificate s29): each flawed worker warns at its first
# call, naming the line of the slow use and its root cause; each fixed twin is silent. Naming the
# fix, and reporting the facts rule's run-time sites per worker (a worker without them is fully
# typed), is the fully-typed certificate: adopted, not built (pending where missing today).
include(joinpath(@__DIR__, "..", "common.jl"))
using TraitWorld, Logging, Test
SHOW = get(ENV, "SHOW", "0") == "1"
toplevel(quote
    @warn_not_fully_typed @trait_module module Teach
    using TraitWorld
    export Col, cv
    @trait Col begin
        cv(c::Col)::Vector{Float64}
    end
    @implement Col Vector{Float64} begin
        cv(c) = c
    end
    # a. a struct field of abstract type, read in the loop
    struct OptsAny; scale; end
    struct OptsF; scale::Float64; end
    a_bad(c::Col, o::OptsAny) = (s = 0.0; for x in cv(c); s += o.scale * x; end; s)
    a_fix(c::Col, o::OptsF) = (s = 0.0; for x in cv(c); s += o.scale * x; end; s)
    # b. a Dict{Symbol, Any} of options, read in the loop
    b_bad(c::Col, o::Dict{Symbol,Any}) = (s = 0.0; for x in cv(c); s += o[:scale] * x; end; s)
    b_fix(c::Col, o::Dict{Symbol,Any}) = (k = o[:scale]::Float64; s = 0.0; for x in cv(c); s += k * x; end; s)
    # c. a non-constant global
    SCALE = 2.0
    const CSCALE = 2.0
    c_bad(c::Col) = (s = 0.0; for x in cv(c); s += SCALE * x; end; s)
    c_fix(c::Col) = (s = 0.0; for x in cv(c); s += CSCALE * x; end; s)
    # d. a captured variable that is reassigned (boxed)
    function d_bad(c::Col)
        s = 0.0
        foreach(x -> (s += x), cv(c))
        return s
    end
    d_fix(c::Col) = sum(x -> x, cv(c))
    # e. a variable whose type changes in the loop
    e_bad(c::Col) = (s = 0; for x in cv(c); s += x; end; s)
    e_fix(c::Col) = (s = 0.0; for x in cv(c); s += x; end; s)
    # f. a type passed as a value to a function it does not own (a kind: a run-time site under the
    #    facts rule, though nothing in it is an abstract value)
    f_bad(c::Col, T::DataType) = (s = 0.0; for x in cv(c); s += convert(T, x); end; s)
    f_fix(c::Col, ::Type{T}) where {T} = (s = 0.0; for x in cv(c); s += convert(T, x); end; s)
    end
end)
T = Main.Teach
v = [1.0, 2.0, 3.0]
cases = [
    ("a abstract field",    () -> T.a_bad(v, T.OptsAny(2.0)),                  () -> T.a_fix(v, T.OptsF(2.0)),       r"scale",          r"::Float64|concrete|declare"),
    ("b Dict{Symbol,Any}",  () -> T.b_bad(v, Dict{Symbol,Any}(:scale => 2.0)), () -> T.b_fix(v, Dict{Symbol,Any}(:scale => 2.0)), r"Dict|getindex", r"assert|::Float64|outside the loop|hoist"),
    ("c non-const global",  () -> T.c_bad(v),                                  () -> T.c_fix(v),                     r"SCALE|global",   r"const"),
    ("d boxed capture",     () -> T.d_bad(v),                                  () -> T.d_fix(v),                     r"box|Box|captur", r"let|Ref|reduce|sum"),
    ("e type changes",      () -> T.e_bad(v),                                  () -> T.e_fix(v),                     r"\bs\b|changes|Union", r"0\.0|initial|zero"),
    ("f kind argument",     () -> T.f_bad(v, Float64),                         () -> T.f_fix(v, Float64),            r"DataType|kind|convert", r"Type\{T\}|where"),
]
function warnings(f)
    lg = TestLogger(min_level = Logging.Warn)
    val = with_logger(() -> Base.invokelatest(f), lg)
    msgs = [string(r.message) for r in lg.logs if r.level >= Logging.Warn]
    return val, join(msgs, "\n")
end
for (name, bad, fix, cause, hint) in cases
    vb, mb = warnings(bad); vf, mf = warnings(fix)
    SHOW && println("---- ", name, "\n", isempty(mb) ? "(silent)" : mb, "\n----")
    check("$name: same value as the fixed twin", vb == vf, "bad $vb, fixed $vf")
    warned = !isempty(mb)
    if !warned && name == "e type changes"
        # a small union is fully typed under the facts rule (its splits are facts): no run-time site
        pending("$name: the flawed worker warns at its first call",
                "a design decision: a variable of a small Union is fully typed (union splits are facts); whether concrete mode warns about it",
                "silent today")
        continue
    end
    check("$name: the flawed worker warns at its first call", warned)
    check("$name: the fixed twin is silent", isempty(mf), first(mf, 200))
    warned || continue
    check("$name: the warning names the line", occursin(r"teach\.jl:\d+|:\d+", mb), first(mb, 200))
    check("$name: the warning names the root cause", occursin(cause, mb), first(mb, 300))
    check("$name: the warning says how to fix it", occursin(hint, mb) || occursin("concrete types", mb), first(replace(mb, '\n' => " | "), 200))
end
# the certificate per worker (TraitWorld's `fully_typed`, built in session 29)
for (name, f, args, expect) in (("a fixed", T.a_fix, (Vector{Float64}, T.OptsF), true), ("a flawed", T.a_bad, (Vector{Float64}, T.OptsAny), false),
                                ("c fixed", T.c_fix, (Vector{Float64},), true), ("c flawed", T.c_bad, (Vector{Float64},), false),
                                ("f fixed", T.f_fix, (Vector{Float64}, Type{Float64}), true), ("f flawed", T.f_bad, (Vector{Float64}, DataType), false))
    r = Base.invokelatest(fully_typed, f, args)
    check("certificate, $name: " * (expect ? "fully typed" : "run-time sites listed"), isfullytyped(r) == expect && (expect || !isempty(r.sites)),
          first(sprint(show, MIME"text/plain"(), r), 200))
end
# To measure after (D) (not run): each pair's steady state under no, all and traits; the fixed
# twins expected equal across modes (fully typed), the flawed ones slower under facts.
summary()
