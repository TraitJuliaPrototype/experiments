# P8: a parametric callback record whose fields are `Callable{Tuple{U, T, Dynamic{IntegratorView{U, T, P}}}, Bool}`
# (Kept{Callable{…}} in a trait module), a `Vector{Callback{U, T, P}}` field of an integrator, the
# callbacks built before U, T, P are known and entered at `init`, and a callback reading `integ.p`
# typed.
# Reference: traits §7.2 (`Callable{A, S}` in a field means Kept), §7.5 (functions kept), §3.1 (an
# argument declared Dynamic{Y}), §7.1 (a declared field read on a kept value has its declared type,
# the parameter value the form fixes). Implemented.
include("common.jl")
header("P8", "struct Callback{U, T, P} with Callable{Tuple{U, T, Dynamic{IntegratorView{U, T, P}}}, Bool} fields; Vector{Callback{U, T, P}} in the integrator")

edef = caught(() -> toplevel(quote
    @trait_module module CBCore
    using TraitWorld
    export IntegratorView, Callback, DiscreteCallback, init, step!
    @trait IntegratorView{U, T, P} begin
        @const u::U
        t::T
        @const p::P
        u_modified::Bool
    end
    "The callback as the integrator keeps it, at the problem's types."
    struct Callback{U, T, P}
        condition::Callable{Tuple{U, T, Dynamic{IntegratorView{U, T, P}}}, Bool}
        affect!::Callable{Tuple{Dynamic{IntegratorView{U, T, P}}}, Nothing}
    end
    "The callback as the user makes it, before U, T, P are known."
    struct DiscreteCallback
        condition::Any
        affect!::Any
    end
    mutable struct Integ{U, T, P}
        const u::U
        t::T
        const p::P
        u_modified::Bool
        const callbacks::Vector{Callback{U, T, P}}
    end
    @implement IntegratorView Integ{U, T, P} where {U, T, P}
    "Enters the user's callbacks at the problem's types."
    function init(u0::U, t0::T, p::P, cbs::Vector{DiscreteCallback}) where {U, T, P}
        kept = Callback{U, T, P}[Callback{U, T, P}(cb.condition, cb.affect!) for cb in cbs]
        return Integ{U, T, P}(copy(u0), t0, p, false, kept)
    end
    "One step, then the callbacks, which see the integrator as a Dynamic{IntegratorView{U, T, P}}."
    function step!(integ::Integ{U, T, P}) where {U, T, P}
        integ.t += one(T)
        iv = Dynamic{IntegratorView{U, T, P}}(integ)
        fired = 0
        for cb in integ.callbacks
            if cb.condition(integ.u, integ.t, iv)
                cb.affect!(iv)
                fired += 1
            end
        end
        return fired
    end
    "One call of the first callback's condition, its result returned as it comes."
    function cond_once(integ::Integ{U, T, P}) where {U, T, P}
        iv = Dynamic{IntegratorView{U, T, P}}(integ)
        return integ.callbacks[1].condition(integ.u, integ.t, iv)
    end
    end
end))
println("trait module: ", errtext(edef))

toplevel(quote
    module Models
    struct Params; a::Float64; end
    struct Params2; b::Int; end
    end
end)
# the user's plain functions
cond_t(u, t, integ) = t >= 2.0
aff_set(integ) = (integ.u[1] = integ.p.a; integ.u_modified = true; nothing)      # reads integ.p: typed?
aff_b(integ) = (integ.u[1] = Float64(integ.p.b); nothing)
getp(integ) = integ.p

callres(f) = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end
show_r(r) = r[1] ? "returned $(repr(r[2]))" : errtext(r[2]; lines = 4)

function run_case(u0, p, cbs, nsteps)
    integ = CBCore.init(u0, 0.0, p, cbs)
    fired = 0
    for _ in 1:nsteps
        fired += CBCore.step!(integ)
    end
    return (fired, integ.u[1], integ.u_modified, typeof(integ.callbacks), typeof(integ.callbacks[1].condition))
end
cbs1 = CBCore.DiscreteCallback[CBCore.DiscreteCallback(cond_t, aff_set)]
cbs2 = CBCore.DiscreteCallback[CBCore.DiscreteCallback(cond_t, aff_b)]
r1 = callres(() -> run_case([0.0, 0.0], Models.Params(7.5), cbs1, 3))
r2 = callres(() -> run_case([0.0], Models.Params2(4), cbs2, 2))
println("P = Params:  ", show_r(r1))
println("P = Params2: ", show_r(r2))

# integ.p read in plain code on the kept view: inferred at P?
DV = edef === nothing ? Dynamic{CBCore.IntegratorView{Vector{Float64}, Float64, Models.Params}} : Nothing
rt = edef === nothing ? Base.return_types(getp, (DV,)) : Any[]
println("return type of `integ.p` on a ", DV, ": ", rt)
rt_t = edef === nothing ? Base.return_types(i -> i.t, (DV,)) : Any[]
println("return type of `integ.t`: ", rt_t)
# a callback with the wrong result type: refused at its call (TypeError)
bad_cond(u, t, integ) = 1
cbs3 = CBCore.DiscreteCallback[CBCore.DiscreteCallback(bad_cond, aff_set)]
r3 = callres(() -> run_case([0.0], Models.Params(1.0), cbs3, 1))
println("a condition returning Int, in the solver's `if`: ", show_r(r3))
r4 = callres(() -> CBCore.cond_once(CBCore.init([0.0], 0.0, Models.Params(1.0), cbs3)))
println("a condition returning Int, its result returned: ", show_r(r4))
# the same with the callback kept Compiled (compiled_for) and Dynamic (with_dynamic) explicitly
cbs3c = CBCore.DiscreteCallback[CBCore.DiscreteCallback(compiled_for(bad_cond), aff_set)]
r5 = callres(() -> CBCore.cond_once(CBCore.init([0.0], 0.0, Models.Params(1.0), cbs3c)))
println("  … kept with compiled_for: ", show_r(r5))
cbs3d = CBCore.DiscreteCallback[CBCore.DiscreteCallback(with_dynamic(bad_cond), aff_set)]
r6 = callres(() -> CBCore.cond_once(CBCore.init([0.0], 0.0, Models.Params(1.0), cbs3d)))
println("  … kept with with_dynamic: ", show_r(r6))
println()

check("the trait module (parametric record of Callable fields, Vector{Callback{U, T, P}} field) is accepted", edef === nothing, errtext(edef))
check("P = Params: the callback fires at t = 2 and 3, writes u[1] = p.a and u_modified",
      r1[1] && r1[2][1:3] == (2, 7.5, true), show_r(r1))
check("P = Params2: a second parameter type works", r2[1] && r2[2][1:2] == (1, 4.0), show_r(r2))
check("`integ.p` read in plain code is inferred at P (Models.Params)", rt == Any[Models.Params], "return_types: $rt")
check("`integ.t` read in plain code is inferred at T (Float64)", rt_t == Any[Float64], "return_types: $rt_t")
check("a condition returning Int is refused at the Callable's call (TypeError), not passed on", !r4[1] && r4[2] isa TypeError, show_r(r4))
check("  … kept with compiled_for: refused at the call (TypeError)", !r5[1] && r5[2] isa TypeError, show_r(r5))
check("  … kept with with_dynamic: refused at the call (TypeError)", !r6[1] && r6[2] isa TypeError, show_r(r6))
finish("P8";
    predicted = "works",
    reference = "traits §7.2, §7.5: a `Callable{A, S}` field in a trait module is Kept{Callable{A, S}}; each call checked; §7.1: a declared field read on a kept value has its declared type at the parameters the form fixes. Implemented",
    prediction = "see the checks: yes where every check is ok")
