# Gate (W-158, sixth part; compiler §7.4, §7.1; traits §9, §7.9, §5.10): compiled code never takes a value that its
# call's type excludes. A call of a function known only as `Callable{A, S}` is inferred as `S`, checked where it is
# called; code compiled for the function's own type calls it as its own. So a call that passes such a function on,
# where the code that runs may be another instance than the one inferred, has its result checked against the type
# inferred for it, in every form: a call left to dispatch, a split's fallback, a constant or `Union{}` result, a
# result two levels up, the function in a field, a tuple or a closure, a splat, `Core.invoke`, a method that does not
# specialize. The same for an operation's result at an argument its members' check does not infer at. The check of
# a `Callable`'s result raises the box's `TypeError` ("in Callable", with its addition for `Nothing`): one check, one
# message. Controls: a box checks its result where it is called; a wrapper is the function (GT-24): passed on as an
# element known by the signature, it is checked as the function is; passed as itself, its result is its own.
# Each verdict is "checked" (the check raised) or "own" (the function's own result reached the caller, typed as it
# is); a value read as a type it excludes, a wrong answer or a stop at `unreachable` fails the gate.
# project: TraitWorld
#     julia --project=<TraitWorld tree> n35_trusted_result.jl
using TraitWorld

defs = quote
const CB = Callable{Tuple{Float64}, Bool}
const CF = Callable{Tuple{Float64}, Float64}
const CN = Callable{Tuple{Float64}, Nothing}
vb() = CB[x -> 1]
vf() = CF[x -> 1]
vn() = CN[x -> 1]
loop_and(v, x) = (n = 0; for t in v; t(x) && (n += 1); end; n)
index_call(v, x) = v[1](x)
all_cl(v, x) = all(t -> t(x), v)
filter_cl(v, x) = filter(t -> t(x), v)
findfirst_cl(v, x) = findfirst(t -> t(x), v)
map_cl(v, x) = map(t -> t(x), v)
sum_cl(v, x) = sum(t -> t(x), v)
comp(v, x) = [t(x) for t in v]
apply1(t, x) = t(x)
helper_b(v, x) = apply1(v[1], x) ? "yes" : "no"
helper_f(v, x) = apply1(v[1], x) + 0.5
helper_n(v, x) = apply1(v[1], x)
appn(::Nothing, x) = 0.0
appn(t, x) = t(x)
pick(v, k) = k > 0 ? v[1] : nothing
split_f(v, x) = appn(pick(v, Int(x)), x) + 0.5
isb(t, x) = t(x) isa Bool
const_b(v, x) = isb(v[1], x) ? "yes" : "no"
@noinline lvl2(t, x) = apply1(t, x)
twolevel_f(v, x) = lvl2(v[1], x) + 0.5
mkc(t) = () -> t(2.0)
capture_f(v, x) = (c = mkc(v[1]); c() + 0.5)
struct Holder{T}; t::T; end
callh(h) = h.t(2.0)
field_f(v, x) = callh(Holder(v[1])) + 0.5
callt(tt) = tt[1](2.0)
tuple_f(v, x) = callt((v[1],)) + 0.5
splat_f(v, x) = apply1(v[1:1]..., x) + 0.5
invoke_f(v, x) = invoke(apply1, Tuple{CF, Float64}, v[1], x) + 0.5
@noinline nsp(@nospecialize(t), x) = t(x)
nospec_f(v, x) = nsp(v[1], x) + 0.5
@noinline nspu(@nospecialize(t), x) = t(x)
nspu(::Nothing, x) = 0.0
split_nospec_f(v, x) = nspu(pick(v, Int(x)), x) + 0.5
nr(t, x) = (r = t(x); r isa Bool && error("a Bool"); r)
noreturn_b(v, x) = (nr(v[1], x); "returned")
end
tdefs = quote
vbox() = CF[Dynamic{CF}(x -> 1)]
vwrap() = CF[compiled_for(x -> 1)]
wrap_own(v, x) = apply1(compiled_for(x -> 1), x) + 0.5         # the wrapper passed as itself: the function's own result
@trait Meas begin
    mstate(x::Meas, s)::Float64                               # a further argument declared abstract
end
struct MA end
mstate(::MA, s) = 1                                           # an Int: the check does not infer at an abstract `s`
@implement Meas MA
vm() = Meas[MA()]
@noinline gstate(m, s) = mstate(m, s)
op_direct(v, x) = mstate(v[1], x) + 0.5
op_passed(v, x) = gstate(v[1], x) + 0.5
end
Core.eval(Main, Expr(:module, true, :Plain, Expr(:block, :(using TraitWorld: Callable), defs.args...)))
Core.eval(Main, Expr(:module, true, :Traits, Expr(:block, :(using TraitWorld), :(@trait_module), defs.args..., tdefs.args...)))

# the function's own result, where it reaches the caller typed as it is
const OWN = Dict(:helper_f => 1.5, :split_f => 1.5, :const_b => "no", :twolevel_f => 1.5, :capture_f => 1.5,
                 :field_f => 1.5, :tuple_f => 1.5, :splat_f => 1.5, :invoke_f => 1.5, :nospec_f => 1.5, :split_nospec_f => 1.5,
                 :noreturn_b => "returned", :wrap_own => 1.5, :sum_cl => 1, :map_cl => [1], :comp => [1])
const ERR = (:loop_and, :all_cl, :filter_cl, :findfirst_cl, :helper_b)   # the own result is no Bool: Julia's error
verdict(f, r, func) =
    r isa TypeError && r.func === func ? :checked :
    r isa TypeError && f in ERR && r.func !== :typeassert && r.func !== :Callable ? :own :
    !(r isa Exception) && haskey(OWN, f) && isequal(r, OWN[f]) && typeof(r) === typeof(OWN[f]) ? :own : :hole
run1(M, f, mk) = try Base.invokelatest(getfield(M, f), Base.invokelatest(getfield(M, mk)), 2.0) catch e; e end

nfail = 0
function expect(what, M, f, mk, func, allowed)
    r = run1(M, f, mk)
    v = verdict(f, r, func)
    ok = v in allowed
    println(rpad("$(nameof(M)) $what $f", 44), v, " ", r isa Exception ? sprint(showerror, r) : repr(r))
    flush(stdout)
    ok || (global nfail += 1)
    return r
end
const forms = (:loop_and, :index_call, :all_cl, :filter_cl, :findfirst_cl, :map_cl, :sum_cl, :comp, :helper_b,
               :helper_f, :split_f, :const_b, :twolevel_f, :capture_f, :field_f, :tuple_f, :splat_f, :invoke_f,
               :nospec_f, :split_nospec_f)
const fforms = (:index_call, :map_cl, :sum_cl, :comp, :helper_f, :split_f, :twolevel_f, :capture_f, :field_f,
                :tuple_f, :splat_f, :invoke_f, :nospec_f, :split_nospec_f)
for M in (Plain, Traits)
    for f in forms
        mk = f in (:loop_and, :all_cl, :filter_cl, :findfirst_cl, :helper_b, :const_b) ? :vb : :vf
        # where the check is made it is the box's: "in Callable"
        expect("plain function", M, f, mk, :Callable, (:checked, :own))
    end
    # the direct call and a call that passes the function on: the box's message, its addition for `Nothing`
    for f in (:index_call, :helper_n)
        r = expect("Nothing", M, f, :vn, :Callable, (:checked,))
        (r isa TypeError && occursin("end the function with `nothing`", sprint(showerror, r))) || (global nfail += 1)
    end
end
for f in fforms
    expect("box", Traits, f, :vbox, :Callable, (:checked,))
    expect("wrapper", Traits, f, :vwrap, :Callable, (:checked, :own))
end
expect("wrapper", Traits, :wrap_own, :vf, :Callable, (:own,))
expect("operation", Traits, :op_direct, :vm, :typeassert, (:checked,))
expect("operation", Traits, :op_passed, :vm, :typeassert, (:checked,))
# last: before the rule, the call read as `Union{}` returns into `unreachable` and the process stops
for M in (Plain, Traits)
    expect("plain function", M, :noreturn_b, :vb, :Callable, (:checked, :own))
end
nfail == 0 || (println("n35_trusted_result: $nfail failed"); exit(1))
println("n35_trusted_result: OK")
