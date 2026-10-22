# P10: a struct parameter bounded by a trait under `@default_with_dynamic_self`: two model types
# from a plain module give one problem type, from the top level and from typed callers; a caller's
# `compiled_for` gives the model's own type; a model type of the trait world stays Compiled.
# Reference: traits §7.4 (the struct's constructor is the bound), §6.3 (the trait's default applies
# at a struct parameter bounded by the trait, to values not of the trait world), §6.4. Implemented.
include("common.jl")
header("P10", "struct Problem{F <: ODERHS} under @default_with_dynamic_self; two plain models give one Problem type")

edef = caught(() -> toplevel(quote
    @trait_module module Core1
    using TraitWorld
    @trait ODERHS begin
        @default_with_dynamic_self
        rhs!(f::ODERHS, du::Vector{Float64}, u::Vector{Float64}, t::Float64)::Nothing
    end
    struct Problem{F <: ODERHS}
        f::F
        u0::Vector{Float64}
    end
    "a model of the trait world: defined in the trait module"
    struct OwnModel; k::Float64; end
    rhs!(m::OwnModel, du::Vector{Float64}, u::Vector{Float64}, t::Float64) = (du .= m.k .* u; nothing)
    @implement ODERHS OwnModel
    function euler(prob::Problem, n::Int)
        u = copy(prob.u0); du = similar(u)
        for _ in 1:n
            rhs!(prob.f, du, u, 0.0)
            u .+= 0.1 .* du
        end
        return u
    end
    end
end))
println("trait module: ", errtext(edef))
edecl = caught(() -> toplevel(quote
    module Models
    using TraitWorld
    using ..Core1
    struct Decay; k::Float64; end
    Core1.rhs!(m::Decay, du::Vector{Float64}, u::Vector{Float64}, t::Float64) = (du .= -m.k .* u; nothing)
    @implement Core1.ODERHS Decay
    struct Growth{G}; g::G; end
    Core1.rhs!(m::Growth, du::Vector{Float64}, u::Vector{Float64}, t::Float64) = (du .= m.g .* u; nothing)
    @implement Core1.ODERHS Growth{G} where {G}
    end
end))
println("models: ", errtext(edecl))

callres(f) = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end
show_r(r) = r[1] ? "returned $(repr(r[2]))" : errtext(r[2]; lines = 4)
typed_decay(m::Models.Decay) = Core1.Problem(m, [1.0])
typed_growth(m::Models.Growth{Float64}) = Core1.Problem(m, [1.0])
typed_own(m::Core1.OwnModel) = Core1.Problem(m, [1.0])
typed_cf(m::Models.Decay) = Core1.Problem(compiled_for(m), [1.0])
rs = [
    ("Decay, top level", callres(() -> typeof(Core1.Problem(Models.Decay(1.0), [1.0])))),
    ("Growth{Float64} (a family member), top level", callres(() -> typeof(Core1.Problem(Models.Growth(0.5), [1.0])))),
    ("Decay, typed caller", callres(() -> typeof(typed_decay(Models.Decay(1.0))))),
    ("Growth{Float64}, typed caller", callres(() -> typeof(typed_growth(Models.Growth(0.5))))),
    ("Decay with compiled_for, typed caller", callres(() -> typeof(typed_cf(Models.Decay(1.0))))),
    ("OwnModel (trait world), typed caller", callres(() -> typeof(typed_own(Core1.OwnModel(2.0))))),
]
for (lbl, r) in rs
    println(rpad(lbl, 48), show_r(r))
end
re1 = callres(() -> Core1.euler(typed_decay(Models.Decay(1.0)), 2))
re2 = callres(() -> Core1.euler(typed_growth(Models.Growth(1.0)), 2))
println("euler with Decay: ", show_r(re1), "; with Growth: ", show_r(re2))
println()

if edef === nothing
    PD = Core1.Problem{Dynamic{Core1.ODERHS}}
    check("Decay at the top level: Problem{Dynamic{ODERHS}}", rs[1][2] == (true, PD), show_r(rs[1][2]))
    check("Growth{Float64} at the top level: Problem{Dynamic{ODERHS}}", rs[2][2] == (true, PD), show_r(rs[2][2]))
    check("Decay from a typed caller: Problem{Dynamic{ODERHS}} (the default over the first-seen rule)", rs[3][2] == (true, PD), show_r(rs[3][2]))
    check("Growth{Float64} from a typed caller: Problem{Dynamic{ODERHS}}", rs[4][2] == (true, PD), show_r(rs[4][2]))
    check("two plain models give one problem type", rs[3][2] == rs[4][2], "$(show_r(rs[3][2])) vs $(show_r(rs[4][2]))")
    check("compiled_for(Decay): Problem{Decay} (a cast wins)", rs[5][2] == (true, Core1.Problem{Models.Decay}), show_r(rs[5][2]))
    check("OwnModel of the trait world, typed: Problem{OwnModel} (the default does not apply)", rs[6][2] == (true, Core1.Problem{Core1.OwnModel}), show_r(rs[6][2]))
    check("the solver runs on both models", re1 == (true, [0.81]) && re2[1] && re2[2] ≈ [1.21], "$(show_r(re1)); $(show_r(re2))")
else
    check("the trait module is accepted", false, errtext(edef))
end
finish("P10";
    predicted = "works (one problem type)",
    reference = "traits §7.4, §6.3: under @default_with_dynamic_self a plain value not of the trait world is Dynamic at the struct parameter: F = Dynamic{ODERHS}",
    prediction = "see the checks: yes where every check is ok")
