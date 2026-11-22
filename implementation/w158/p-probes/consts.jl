# C-158, seventh part: a constant read from the instance at the signature, at `Core.invoke` and at a splat
# (compiler §7.4: "At a marked call the result is its type alone"). A function known only as `Callable{A, S}` returns
# an `Int` where `Bool` is declared; `isb(t, x) = t(x) isa Bool` is `true` at the signature (inferred as a constant)
# and `false` in the function's own instance. Verdicts as `m-probes/forms.jl`: `own` ("no", the function's own answer),
# `checked` (the check raised), `HOLE` ("yes": the constant read at the signature, which the instance that ran does not
# give). The same for an operation whose result its members' check does not reach. `TW=1`: the library loaded.
# `julia [--project=<TraitWorld>] p-probes/consts.jl`; `PATCH=<file>` includes a file first. Exits 1 on a hole.
haskey(ENV, "PATCH") && include(ENV["PATCH"])
const TW = get(ENV, "TW", "") == "1"
TW && using TraitWorld
TW || (const Callable = Core.Callable)
const CB = Callable{Tuple{Float64}, Bool}
vb() = CB[x -> 1]
isb(t, x) = t(x) isa Bool
@noinline isbn(t, x) = t(x) isa Bool
invoke_c(v, x) = invoke(isb, Tuple{CB, Float64}, v[1], x) ? "yes" : "no"
invoke_n(v, x) = invoke(isbn, Tuple{CB, Float64}, v[1], x) ? "yes" : "no"
invoke_any(v, x) = invoke(isbn, Tuple{Any, Any}, v[1], x) ? "yes" : "no"
splat_c(v, x) = isb(v[1:1]..., x) ? "yes" : "no"
splat_t(v, x) = isbn((v[1], x)...) ? "yes" : "no"
splat_v(v, x) = isbn(Any[v[1], x]...) ? "yes" : "no"
apply_c(v, x) = Core._apply_iterate(iterate, isbn, (v[1],), (x,)) ? "yes" : "no"
cases = Any[("Core.invoke at the signature", :invoke_c, :vb), ("Core.invoke, @noinline", :invoke_n, :vb),
            ("Core.invoke at Any", :invoke_any, :vb), ("a splat of a slice", :splat_c, :vb),
            ("a splat of a tuple", :splat_t, :vb), ("a splat of a Vector{Any}", :splat_v, :vb),
            ("Core._apply_iterate", :apply_c, :vb)]
if TW
    @eval begin
        @trait CMeas begin
            cstate(x::CMeas, s)::Bool          # a further argument declared abstract
        end
        struct CMA end
        cstate(::CMA, s) = 1
        @implement CMeas CMA
        vm() = CMeas[CMA()]
        isbo(m, s) = cstate(m, s) isa Bool
        op_invoke(v, x) = invoke(isbo, Tuple{CMeas, Any}, v[1], x) ? "yes" : "no"
        op_splat(v, x) = isbo((v[1], x)...) ? "yes" : "no"
    end
    push!(cases, ("an operation's result, Core.invoke", :op_invoke, :vm), ("an operation's result, a splat", :op_splat, :vm))
end
println("TW=", TW, " PATCH=", get(ENV, "PATCH", ""), " julia ", Base.GIT_VERSION_INFO.commit_short)
nh = 0
for (name, f, mk) in cases
    r = try Base.invokelatest(getfield(Main, f), Base.invokelatest(getfield(Main, mk)), 2.0) catch e; e end
    v = r == "no" ? "own" : r isa TypeError && r.func in (:typeassert, :Callable) ? "checked ($(r.func), got $(repr(r.got)))" :
        r == "yes" ? (global nh += 1; "HOLE (the constant read at the signature)") : "error $(sprint(showerror, r))"
    println(rpad(name, 40), v)
end
println("\n", nh, " holes in ", length(cases), " forms")
exit(nh > 0 ? 1 : 0)
