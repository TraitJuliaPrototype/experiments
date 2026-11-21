# C-157, the pattern's scan: a function kept as itself in a `Vector{Callable{A, S}}`, whose result is no `S`, called
# in each common form. Per form: what the call gives, and the verdict:
#   checked   the result's check raised (TypeError, its `func` printed)
#   own       the function's own result reached the code that called it, typed as it is (no type was trusted)
#   HOLE      code compiled for the set's declared result received a value outside it: a wrong answer or a
#             value read as a type it is not
# Plain Julia's `Core.Callable`, the forms at Main; `TW=1`: the library loaded, the forms in a trait module (code
# compiled by facts). `PATCH=1` lays l-probes/patch_l.jl over the session first. Exits with 1 where a hole is found.
get(ENV, "PATCH", "") == "1" && include(joinpath(@__DIR__, "patch_l.jl"))
const TW = get(ENV, "TW", "") == "1"
TW && using TraitWorld
TW || (const Callable = Core.Callable)
defs = quote
const VB = Vector{Callable{Tuple{Float64}, Bool}}
const VF = Vector{Callable{Tuple{Float64}, Float64}}
vb() = Callable{Tuple{Float64}, Bool}[x -> 1]          # returns an Int where a Bool is declared
vf() = Callable{Tuple{Float64}, Float64}[x -> 1]       # returns an Int where a Float64 is declared

loop_and(v::VB, x) = (n = 0; for t in v; t(x) && (n += 1); end; n)
loop_sum(v::VF, x) = (s = 0.0; for t in v; s += t(x); end; s)
index_call(v::VF, x) = v[1](x)
all_cl(v::VB, x) = all(t -> t(x), v)
any_cl(v::VB, x) = any(t -> t(x), v)
count_cl(v::VB, x) = count(t -> t(x), v)
filter_cl(v::VB, x) = filter(t -> t(x), v)
findfirst_cl(v::VB, x) = findfirst(t -> t(x), v)
map_cl(v::VF, x) = map(t -> t(x), v)
sum_cl(v::VF, x) = sum(t -> t(x), v)
foldl_cl(v::VF, x) = foldl((a, t) -> a + t(x), v; init = 0.0)
gen_sum(v::VF, x) = sum(t(x) for t in v)
comp(v::VF, x) = [t(x) for t in v]
apply1(t, x) = t(x)
helper_b(v::VB, x) = apply1(v[1], x) ? "yes" : "no"
helper_f(v::VF, x) = apply1(v[1], x) + 0.5
end
if TW
    Core.eval(Main, Expr(:toplevel, :(module Forms
        using TraitWorld
        @trait_module
        $(defs.args...)
        end), :(using .Forms: VB, VF, vb, vf, loop_and, loop_sum, index_call, all_cl, any_cl, count_cl, filter_cl,
                findfirst_cl, map_cl, sum_cl, foldl_cl, gen_sum, comp, helper_b, helper_f)))
else
    Core.eval(Main, defs)
end
println("TW=", TW, " PATCH=", get(ENV, "PATCH", ""))

cases = [
    ("loop: t(x) && …",            loop_and,      vb, :check),
    ("loop: s += t(x)",            loop_sum,      vf, :check),
    ("v[1](x)",                    index_call,    vf, :check),
    ("all(t -> t(x), v)",          all_cl,        vb, :pass),
    ("any(t -> t(x), v)",          any_cl,        vb, :pass),
    ("count(t -> t(x), v)",        count_cl,      vb, :pass),
    ("filter(t -> t(x), v)",       filter_cl,     vb, :pass),
    ("findfirst(t -> t(x), v)",    findfirst_cl,  vb, :pass),
    ("map(t -> t(x), v)",          map_cl,        vf, :pass),
    ("sum(t -> t(x), v)",          sum_cl,        vf, :pass),
    ("foldl((a, t) -> a + t(x))",  foldl_cl,      vf, :pass),
    ("sum(t(x) for t in v)",       gen_sum,       vf, :pass),
    ("[t(x) for t in v]",          comp,          vf, :pass),
    ("apply1(v[1], x) ? … : …",    helper_b,      vb, :pass),
    ("apply1(v[1], x) + 0.5",      helper_f,      vf, :pass),
]
# what each call would give with the function's own result taken as it is (the `own` reading)
own = Dict("all(t -> t(x), v)" => :error, "any(t -> t(x), v)" => :error, "count(t -> t(x), v)" => :error,
           "filter(t -> t(x), v)" => :error, "findfirst(t -> t(x), v)" => :error,
           "map(t -> t(x), v)" => [1], "sum(t -> t(x), v)" => 1, "foldl((a, t) -> a + t(x))" => 1.0,
           "sum(t(x) for t in v)" => 1, "[t(x) for t in v]" => [1], "apply1(v[1], x) ? … : …" => :error,
           "apply1(v[1], x) + 0.5" => 1.5)
nh = 0
for (name, f, mk, kind) in cases
    r = try Base.invokelatest(f, Base.invokelatest(mk), 2.0) catch e; e end
    verdict = if r isa TypeError && r.func in (:typeassert, :Callable)
        "checked ($(r.func), expected $(r.expected), got $(repr(r.got)))"
    elseif r isa TypeError && get(own, name, nothing) === :error
        "own (Julia's error at the value: $(r.func), $(sprint(showerror, r)))"
    elseif !(r isa Exception) && haskey(own, name) && own[name] isa Union{Number, Vector} && isequal(r, own[name]) && typeof(r) == typeof(own[name])
        "own ($(repr(r)))"
    else
        global nh += 1
        "HOLE ($(r isa Exception ? sprint(showerror, r) : repr(r)))"
    end
    println(rpad(name, 30), verdict)
end
println("\n", nh, " holes in ", length(cases), " forms")
exit(nh > 0 ? 1 : 0)
