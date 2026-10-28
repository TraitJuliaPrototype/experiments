# E-218 (W-80, SciML's X6): a capability chosen by the stored object's traits, on an integrator. Two integrator
# types, one with `HasDu`; a callback with a method bounded `IntegratorView` and one bounded
# `(IntegratorView, HasDu)`; both integrators stored as `Dynamic{IntegratorView}`.
#     julia --project=TraitWorld experiments/w80/x6.jl
using TraitWorld
@trait_module module X6
using TraitWorld
export IntegratorView, HasDu, IntA, IntB, cb, cbplain, run_cb, run_plain
@trait IntegratorView begin
    tnow(i::IntegratorView)::Float64
    state(i::IntegratorView)::Vector{Float64}
end
@trait HasDu begin
    du(i::HasDu)::Vector{Float64}
end
mutable struct IntA; t::Float64; u::Vector{Float64}; end
mutable struct IntB; t::Float64; u::Vector{Float64}; d::Vector{Float64}; end
@implement IntegratorView IntA begin
    tnow(i) = i.t
    state(i) = i.u
end
@implement IntegratorView IntB begin
    tnow(i) = i.t
    state(i) = i.u
end
@implement HasDu IntB begin
    du(i) = i.d
end
cb(i::IntegratorView) = tnow(i) + state(i)[1]                        # what every integrator can do
cb(i::(IntegratorView, HasDu)) = tnow(i) + state(i)[1] + du(i)[1]    # what a capable one can do
cbplain(i::IntegratorView) = tnow(i) + state(i)[1]
function run_cb(is::Vector{Dynamic{IntegratorView}}, n::Int)
    s = 0.0
    for _ in 1:n, i in is
        s += cb(i)
    end
    return s
end
function run_plain(is::Vector{Dynamic{IntegratorView}}, n::Int)
    s = 0.0
    for _ in 1:n, i in is
        s += cbplain(i)
    end
    return s
end
end
using .X6
a = IntA(1.0, [10.0]); b = IntB(2.0, [20.0], [300.0])
is = Dynamic{IntegratorView}[Dynamic{IntegratorView}(a), Dynamic{IntegratorView}(b)]
println("X6 selected: IntA ", cb(is[1]), " (want 11.0), IntB ", cb(is[2]), " (want 322.0)")
run_cb(is, 10); run_plain(is, 10)
n = 10^6
t1 = minimum(@elapsed(run_cb(is, n)) for _ in 1:5) / (2n)
t2 = minimum(@elapsed(run_plain(is, n)) for _ in 1:5) / (2n)
println("X6 per call: the capability chosen ", round(t1 * 1e9; digits = 2), " ns; one bound ", round(t2 * 1e9; digits = 2), " ns")
