# W-161, the merge's gate (E-496): the positive membership decided where the type is known (W-160 (a): `new`'s
# field test, `isa`, a store) rests on its edge to the membership's method, and a membership taken back (W-155b,
# D-13) reaches that edge. A box made through a forwarder at a known member, an `isa` folded true and a store into
# storage typed by the trait: each compiled, then the membership deleted; each piece of code ends, and the calls
# answer by the new world (traits §5.13, §7.8; compiler §4.8, §5.5, §5.6).
#     julia --project=<TraitWorld-unified> delete_forwarder.jl
using TraitWorld, Test

toplevel(q) = Core.eval(Main, Expr(:toplevel, q.args...))
latest(f, args...) = Base.invokelatest(f, args...)
# the valid CodeInstance of `f` at the argument types `T`, or nothing
function code_of(f, T)
    for m in methods(f), mi in Base.specializations(m)
        (mi isa Core.MethodInstance && mi.specTypes === Tuple{typeof(f), T.parameters...} && isdefined(mi, :cache)) || continue
        ci = mi.cache
        while true
            ci.max_world == typemax(UInt) && return ci
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
    return nothing
end
# whether a CodeInstance rests on a membership's method (`Core.implements` at a pair): an edge of its own, or of a
# callee's code it names (the forwarder's, the box's constructor's), to depth 3
is_implements(e) = (e isa Core.MethodInstance && e.def isa Method && e.def.name === :implements) ||
                   (e isa Core.CodeInstance && e.def.def isa Method && e.def.def.name === :implements)
implements_edge(ci, depth = 0) = any(e -> is_implements(e) ||
    (depth < 3 && e isa Core.CodeInstance && implements_edge(e, depth + 1)), ci.edges)
implements_own(ci) = any(is_implements, ci.edges)

toplevel(quote
    module FwdDel
    using TraitWorld
    @trait_module bounded = false
    @trait Model begin
        @default_dynamic
        rate(m::Model, u::Float64)::Float64
    end
    struct Decay; k::Float64; end
    rate(d::Decay, u::Float64) = -d.k * u
    @implement Model Decay
    solve(m::Model, u::Float64) = rate(m, u)     # erases by default: a forwarder boxes a plain member
    runit(d::Decay) = solve(d, 2.0)              # the forwarder at a known member: the box made by `new`
    mkbox(d::Decay) = Dynamic{Model}(d)          # the box's constructor at a known member
    isit(d::Decay) = d isa Model                 # an `isa` folded true
    const STORE = Model[]
    store!(d::Decay) = (push!(STORE, d); nothing) # a store into storage typed by the trait
    end
end)

@testset "a membership taken back ends the code that decided it where the type is known" begin
    M = getglobal(Main, :FwdDel)
    d = M.Decay(0.5)
    @test latest(M.runit, d) == -1.0
    @test latest(M.mkbox, d) isa Dynamic{M.Model}
    @test latest(M.isit, d)
    latest(M.store!, d)
    codes = Dict(:runit => code_of(M.runit, Tuple{M.Decay}), :mkbox => code_of(M.mkbox, Tuple{M.Decay}),
                 :isit => code_of(M.isit, Tuple{M.Decay}), :store! => code_of(M.store!, Tuple{M.Decay}))
    for (k, ci) in codes
        @test ci !== nothing
        ci === nothing && continue
        println(rpad(k, 8), " the membership's edge: its own ", implements_own(ci), ", through a callee's code ", implements_edge(ci))
        @test implements_edge(ci)
    end
    delete_membership(M.Model, M.Decay)
    for (k, ci) in codes
        ci === nothing && continue
        println(rpad(k, 8), " ended: ", ci.max_world != typemax(UInt))
        @test ci.max_world != typemax(UInt)
    end
    # the calls answer by the new world
    @test !latest(M.isit, d)
    @test_throws MethodError latest(M.runit, d)          # no method of solve takes a Decay now
    @test_throws TypeError latest(M.mkbox, d)            # the box's field test refuses it
    @test_throws Exception latest(M.store!, d)           # the store's test refuses it
end
