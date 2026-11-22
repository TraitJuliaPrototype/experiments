# C-157, sixth part: every form in which a call's type can rest on a declared result whose members' own code is
# not checked against it (compiler §7.4), and the controls. Per form: what the call gives, and the verdict:
#   checked   the declared result's check raised (TypeError; its `func` printed: `Callable` is the box's)
#   own       the function's own result reached the caller, typed as it is (no type was trusted)
#   HOLE      code compiled for a declared result received a value outside it: a wrong answer, or a value read
#             as a type it is not
# Plain Julia's `Core.Callable`, the forms at Main; `TW=1`: the library loaded, the forms in a trait module (code
# compiled by facts), with the boxes', the wrappers' and an operation's forms beside. `PATCH=<file>` includes a file
# first (a compiler change laid over the session). `ONLY=<name>` runs one form. Exits with 1 where a hole is found.
# A form that would read past `unreachable` (the call's type `Union{}`) runs in a child process (`noreturn`).
haskey(ENV, "PATCH") && include(ENV["PATCH"])
const TW = get(ENV, "TW", "") == "1"
TW && using TraitWorld
TW || (const Callable = Core.Callable)
defs = quote
const CB = Callable{Tuple{Float64}, Bool}
const CF = Callable{Tuple{Float64}, Float64}
const VB = Vector{CB}
const VF = Vector{CF}
vb() = CB[x -> 1]                     # returns an Int where a Bool is declared
vf() = CF[x -> 1]                     # returns an Int where a Float64 is declared

# 1. a call left to dispatch, no case: the function passed on to code compiled for its own type
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
map_f(v::VF, x) = map(v[1], [x])                       # the function itself passed to `map`
# 2. two methods take the call: no case is made
twom(t::Function, x) = t(x)
twom(t, x) = t(x)
twom_f(v::VF, x) = twom(v[1], x) + 0.5
# 3. a union split's fallback: `Nothing` is a case, the rest is left to dispatch
appn(::Nothing, x) = 0.0
appn(t, x) = t(x)
pick(v::VF, k) = k > 0 ? v[1] : nothing
split_f(v::VF, x) = appn(pick(v, Int(x)), x) + 0.5
# 4. a call whose result inference took as a constant
isb(t, x) = t(x) isa Bool
const_b(v::VB, x) = isb(v[1], x) ? "yes" : "no"
# 5. a call whose result inference took as `Union{}` (never returns): at the signature the result is a `Bool` and
# the function raises, at the function's own type it returns
nr(t, x) = (r = t(x); r isa Bool && error("a Bool"); r)
noreturn_b(v::VB, x) = (nr(v[1], x); "returned")
# 6. a result that flows into a caller two levels up
@noinline lvl2(t, x) = apply1(t, x)
twolevel_f(v::VF, x) = lvl2(v[1], x) + 0.5
# 7. the function in a closure's capture
mkc(t) = () -> t(2.0)
capture_f(v::VF, x) = (c = mkc(v[1]); c() + 0.5)
# 8. the function in a field of a parametric struct
struct Holder{T}; t::T; end
callh(h) = h.t(2.0)
field_f(v::VF, x) = callh(Holder(v[1])) + 0.5
# 9. the function in a tuple
callt(tt) = tt[1](2.0)
tuple_f(v::VF, x) = callt((v[1],)) + 0.5
# 10. a splat: `Core._apply_iterate`
splat_f(v::VF, x) = apply1(v[1:1]..., x) + 0.5
# 11. `Core.invoke` at the signature
invoke_f(v::VF, x) = invoke(apply1, Tuple{CF, Float64}, v[1], x) + 0.5
# 12. a method that does not specialize on the function: compiled at the declared type, inferred at the call's
@noinline nsp(@nospecialize(t), x) = t(x)
nospec_f(v::VF, x) = nsp(v[1], x) + 0.5
@noinline nspu(@nospecialize(t), x) = t(x)
nspu(::Nothing, x) = 0.0
split_nospec_f(v::VF, x) = nspu(pick(v, Int(x)), x) + 0.5
# 13. the latest world
latest_f(v::VF, x) = Base.invokelatest(apply1, v[1], x) + 0.5
# 14. a value computed by inference (facts §7): the element type `map` gives an empty vector
promote_f(v::VF, x) = Base.promote_op(t -> t(x), eltype(v))
end

TW && (wdefs = quote
# the controls: a box checks its result where it is called; a wrapper is the function, unchecked (GT-24)
vbox() = CF[Dynamic{CF}(x -> 1)]
vwrap() = CF[compiled_for(x -> 1)]
# an operation whose result its members' check does not reach: a further argument declared abstract (traits §5.10)
@trait Meas begin
    mstate(x::Meas, s)::Float64
end
struct MA end
mstate(::MA, s) = 1                   # an Int where a Float64 is declared: not inferred at the check
@implement Meas MA
vm() = Meas[MA()]
@noinline gstate(m, s) = mstate(m, s)
op_direct(v::Vector{Meas}, x) = mstate(v[1], x) + 0.5          # the operation's call at the set: asserted
op_passed(v::Vector{Meas}, x) = gstate(v[1], x) + 0.5          # passed on to code compiled for MA
end)

if TW
    Core.eval(Main, Expr(:toplevel, :(module Forms
        using TraitWorld
        @trait_module
        $(defs.args...)
        $(wdefs.args...)
        end), :(using .Forms)))
else
    Core.eval(Main, defs)
end
const M = TW ? getfield(Main, :Forms) : Main

cases = Any[
    ("loop: t(x) && …",            :loop_and,      :vb),
    ("loop: s += t(x)",            :loop_sum,      :vf),
    ("v[1](x)",                    :index_call,    :vf),
    ("all(t -> t(x), v)",          :all_cl,        :vb),
    ("any(t -> t(x), v)",          :any_cl,        :vb),
    ("count(t -> t(x), v)",        :count_cl,      :vb),
    ("filter(t -> t(x), v)",       :filter_cl,     :vb),
    ("findfirst(t -> t(x), v)",    :findfirst_cl,  :vb),
    ("map(t -> t(x), v)",          :map_cl,        :vf),
    ("sum(t -> t(x), v)",          :sum_cl,        :vf),
    ("foldl((a, t) -> a + t(x))",  :foldl_cl,      :vf),
    ("sum(t(x) for t in v)",       :gen_sum,       :vf),
    ("[t(x) for t in v]",          :comp,          :vf),
    ("apply1(v[1], x) ? … : …",    :helper_b,      :vb),
    ("apply1(v[1], x) + 0.5",      :helper_f,      :vf),
    ("map(v[1], [x])",             :map_f,         :vf),
    ("two methods",                :twom_f,        :vf),
    ("a union split's fallback",   :split_f,       :vf),
    ("a constant result",          :const_b,       :vb),
    ("a result Union{}",           :noreturn_b,    :vb),
    ("two levels up",              :twolevel_f,    :vf),
    ("a closure's capture",        :capture_f,     :vf),
    ("a struct's field",           :field_f,       :vf),
    ("a tuple's element",          :tuple_f,       :vf),
    ("a splat",                    :splat_f,       :vf),
    ("Core.invoke",                :invoke_f,      :vf),
    ("@nospecialize",              :nospec_f,      :vf),
    ("a split's case, no specializing", :split_nospec_f, :vf),
    ("invokelatest",               :latest_f,      :vf),
]
if TW
    for (n, f, mk) in copy(cases)
        mk === :vf && push!(cases, ("box: " * n, f, :vbox))
    end
    for (n, f, mk) in copy(cases)
        mk === :vf && push!(cases, ("wrapper: " * n, f, :vwrap))
    end
    push!(cases, ("operation at the set", :op_direct, :vm), ("operation passed on", :op_passed, :vm))
end
haskey(ENV, "ONLY") && filter!(c -> c[2] === Symbol(ENV["ONLY"]), cases)

# what each call gives with the function's own result taken as it is (the `own` reading): Julia's error at the
# value, or the value
own = Dict(:all_cl => :error, :any_cl => :error, :count_cl => :error, :filter_cl => :error, :findfirst_cl => :error,
           :map_cl => [1], :sum_cl => 1, :foldl_cl => 1.0, :gen_sum => 1, :comp => [1], :helper_b => :error,
           :helper_f => 1.5, :map_f => [1], :twom_f => 1.5, :split_f => 1.5, :const_b => "no",
           :noreturn_b => "returned", :twolevel_f => 1.5, :capture_f => 1.5, :field_f => 1.5, :tuple_f => 1.5,
           :splat_f => 1.5, :invoke_f => 1.5, :nospec_f => 1.5, :split_nospec_f => 1.5, :latest_f => 1.5, :op_passed => 1.5)
println("TW=", TW, " PATCH=", get(ENV, "PATCH", ""), " julia ", Base.GIT_VERSION_INFO.commit_short)

function verdict(name, f, r)
    if r isa TypeError && r.func in (:typeassert, :Callable)
        return "checked ($(r.func), expected $(r.expected), got $(repr(r.got)))", false
    elseif r isa Exception && get(own, f, nothing) === :error
        return "own (Julia's error at the value: $(sprint(showerror, r)))", false
    elseif !(r isa Exception) && haskey(own, f) && !(own[f] isa Symbol) && isequal(r, own[f]) && typeof(r) == typeof(own[f])
        return "own ($(repr(r)))", false
    end
    return "HOLE ($(r isa Exception ? sprint(showerror, r) : repr(r)))", true
end
nh = 0
for (name, f, mk) in cases
    if f === :noreturn_b && get(ENV, "FORMS_CHILD", "") != "1"
        # in a child process (one, never more): reading past `unreachable` may stop the process
        cmd = addenv(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $(@__FILE__)`,
                     "FORMS_CHILD" => "1", "ONLY" => "noreturn_b")
        out = IOBuffer()
        run(pipeline(ignorestatus(cmd); stdout = out, stderr = out))
        s = String(take!(out))
        lines = filter(l -> startswith(l, "a result Union{}"), split(s, '\n'))
        if isempty(lines)
            global nh += 1
            println(rpad(name, 32), "HOLE (the process stopped: ", replace(first(s, 300), '\n' => ' '), ")")
        else
            println(lines[1]); occursin("HOLE", lines[1]) && (global nh += 1)
        end
        continue
    end
    r = try Base.invokelatest(getfield(M, f), Base.invokelatest(getfield(M, mk)), 2.0) catch e; e end
    v, hole = verdict(name, f, r)
    hole && (global nh += 1)
    println(rpad(name, 32), v)
end
let r = Base.invokelatest(getfield(M, :promote_f), Base.invokelatest(getfield(M, :vf)), 2.0)
    haskey(ENV, "ONLY") || println("promote_op at the signature: ", r, " (a value computed by inference, facts §7)")
end
haskey(ENV, "ONLY") || println("\n", nh, " holes in ", length(cases), " forms")
exit(nh > 0 ? 1 : 0)
