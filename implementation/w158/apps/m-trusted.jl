# W-158, sixth part (compiler §7.4, §7.6; C-157): a function known only as `Callable{A, S}` whose result is no `S`,
# passed on in the forms of `m-probes/forms.jl`, and an operation's result its members' check does not reach. In a
# session the call that passes it is checked against the type inferred for it; in a closed build no call is left to
# dispatch: each call of the function branches over the signature's members, its result asserted in each branch.
# Both raise `TypeError` at the value 1 in every form, or give the function's own answer where no type was trusted
# (not printed: a constant read at the signature is the function's own answer in a session where the call is left to
# dispatch, and raises where its body runs at the signature, as in a closed build); the output prints the check's
# name (`Callable`: the box's `TypeError`; `typeassert`: an operation's) and the value got, not the check's type, which
# differs by where the check is. The forms with the function in a struct's field or a
# closure's capture are not here: a closed build joins the record of each member at its bare type (`Holder`), and
# leaves the call at it unresolved (`m-probes/forms.jl` has them in a session).
# `julia --project=<TraitWorld> apps/m-trusted.jl` runs `main` in a session.
using TraitWorld
const CB = Callable{Tuple{Float64}, Bool}
const CF = Callable{Tuple{Float64}, Float64}
const CN = Callable{Tuple{Float64}, Nothing}
one_b(x::Float64) = 1
one_f(x::Float64) = 1
one_n(x::Float64) = 1
two_f(x::Float64) = 2x
apply1(t, x) = t(x)
@noinline lvl2(t, x) = apply1(t, x)
callt(tt) = tt[1](2.0)
@noinline nsp(@nospecialize(t), x) = t(x)
nr(t, x) = (r = t(x); r isa Bool && error("a Bool"); r)
@trait MMeas begin
    mmstate(x::MMeas, s)::Float64                   # a further argument declared abstract
end
struct MMA end
mmstate(::MMA, s) = 1
@implement MMeas MMA
@noinline gmstate(m, s) = mmstate(m, s)

fmt(x) = x isa Float64 ? string(x::Float64) : x isa String ? (x::String) : x isa Int ? string(x::Int) :
         x isa Bool ? string(x::Bool) : x === nothing ? "nothing" : "another value"
function show1(name::String, f)
    s = try
        fmt(f())
    catch e
        e isa TypeError ? "TypeError in " * string(e.func::Symbol) * (e.got isa Int ? ", got " * string(e.got::Int) : "") :
            "another error"
    end
    println(Core.stdout, name, ": ", s)
end

function (@main)(args::Vector{String})::Cint
    n = length(args)
    vb = CB[one_b]
    vf = CF[n > 5 ? two_f : one_f]
    vn = CN[one_n]
    vw = CF[compiled_for(one_f)]
    vd = CF[Dynamic{CF}(one_f)]
    vm = MMeas[MMA()]
    x = 2.0 + n
    show1("direct", () -> vf[1](x))
    show1("all", () -> all(t -> t(x), vb))
    show1("any", () -> any(t -> t(x), vb))
    show1("findfirst", () -> something(findfirst(t -> t(x), vb), 0))
    show1("map", () -> map(t -> t(x), vf)[1])
    show1("sum", () -> sum(t -> t(x), vf))
    show1("comprehension", () -> [t(x) for t in vf][1])
    show1("apply1 ?", () -> apply1(vb[1], x) ? "yes" : "no")
    show1("apply1 +", () -> apply1(vf[1], x) + 0.5)
    show1("two levels", () -> lvl2(vf[1], x) + 0.5)
    show1("tuple", () -> callt((vf[1],)) + 0.5)
    show1("nospecialize", () -> nsp(vf[1], x) + 0.5)
    show1("noreturn", () -> (nr(vb[1], x); "returned"))
    show1("Nothing", () -> apply1(vn[1], x))
    show1("wrapper", () -> map(t -> t(x), vw)[1])
    show1("box", () -> map(t -> t(x), vd)[1])
    show1("operation", () -> gmstate(vm[1], nothing) + 0.5)
    show1("kept", () -> map(t -> t(x), CF[two_f])[1])
    return 0
end
