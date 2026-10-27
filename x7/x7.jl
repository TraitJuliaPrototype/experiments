# E-182 (W-60's X7): loading stubs and the waist at small scale, TraitMakie (trait) against PlainPlots (plain).
#     X7_KIND=trait|plain X7_CASE=world|waist|handover|cost [X7_ENTRY=direct|latest] [X7_PROV=plain|sparse] julia --project=env x7.jl
# world:    a first `hist2!` (the provider loaded by a stub) and a `save` in one function (B1)
# waist:    a first render of the core's recipes, then the provider loaded (with SparseArrays or without), then the
#           same figure rendered again: the core's CodeInstances invalidated, and the second render's time (B3)
# handover: (trait only; X7_FORM=direct|handover) a plot type of a plain module implementing `Plot`, its operations calling plain helpers
#           directly or through `Dynamic{Callable}`s: CodeInstances of owner :facts in that module (B2)
# cost:     the stub's and the entry's cost per call
const KIND = get(ENV, "X7_KIND", "trait")
const CASE = get(ENV, "X7_CASE", "world")
const ENTRY = get(ENV, "X7_ENTRY", "direct")
const PROV = get(ENV, "X7_PROV", "plain")
if KIND == "trait"
    using TraitMakie, TraitWorld
    const PL = TraitMakie
    const CORE_MODS = (TraitMakie, TraitMakie.PlotCore)
    const PROVIDER = PROV == "sparse" ? "X7StatsSparse" : "X7Stats"
else
    using PlainPlots
    const PL = PlainPlots
    const CORE_MODS = (PlainPlots,)
    const PROVIDER = PROV == "sparse" ? "X7PlainStatsSparse" : "X7PlainStats"
end

# the loading stub, in plain code: the provider loaded at the first call, its own function called in the latest world
const LOADED = Ref{Any}(nothing)
function hist2!(fig, x; kw...)
    m = LOADED[] === nothing ? (LOADED[] = Base.require(Base.identify_package(PROVIDER))) : LOADED[]
    return Base.invokelatest(m.hist2!, fig, x; kw...)
end
# the user-facing entry: direct, or through `invokelatest` (the memo's rule for entries that can reach code loaded on demand)
save_entry(path, fig) = ENTRY == "latest" ? Base.invokelatest(PL.save, path, fig) : PL.save(path, fig)

const DATA = [sin(0.37k) + 0.1 * cos(1.3k) for k in 1:500]
mkpath(joinpath(@__DIR__, "out"))
out(n) = joinpath(@__DIR__, "out", "$(KIND)-$(n).png")

"Every CodeInstance of the methods of `mods` (their own methods), with its owner."
function cis(mods)
    s = Base.IdSet{Core.CodeInstance}()
    Base.visit(isdefined(Core, :GlobalMethods) ? Core.GlobalMethods : Core.methodtable) do m
        m.module in mods || return
        for mi in Base.specializations(m)
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci isa Core.CodeInstance
                push!(s, ci)
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    return s
end
valid(ci) = ci.max_world == typemax(UInt)
ctime() = Base.cumulative_compile_time_ns()[1] / 1e9
Base.cumulative_compile_timing(true)

if CASE == "world"
    function f()
        fig = PL.figure(; title = "x7")
        PL.lines!(fig, [1.0, 2.0, 3.0], [-1.0, 0.0, 1.0])
        hist2!(fig, DATA; bins = 12)
        save_entry(out("world-$ENTRY"), fig)
        return fig
    end
    r = try
        f(); "ok"
    catch e
        "error: " * first(replace(sprint(showerror, e), '\n' => " | "), 220)
    end
    println("X kind=$KIND case=world entry=$ENTRY result=$r")
elseif CASE == "waist"
    fig = PL.figure(; title = "x7")
    PL.lines!(fig, [1.0, 2.0, 3.0], [-1.0, 0.0, 1.0])
    PL.scatter!(fig, [1.0, 2.0, 3.0], [0.5, 0.0, -0.5])
    PL.hist!(fig, DATA; bins = 12)
    PL.save(out("waist-1"), fig)
    t1 = @elapsed PL.save(out("waist-1"), fig)
    before = filter(valid, cis(CORE_MODS))
    nfacts = count(ci -> ci.owner === :facts, before)
    tl = @elapsed hist2!(PL.figure(), DATA; bins = 12)       # the provider loads here
    lost = filter(!valid, collect(before))
    c = ctime()
    t2 = @elapsed PL.save(out("waist-2"), fig)                 # the core's figure again, after the load
    c2 = ctime() - c
    println("X kind=$KIND case=waist prov=$PROV sparse_loaded=$(any(k -> k.name == "SparseArrays", keys(Base.loaded_modules))) ",
            "core_cis_valid_before=$(length(before)) (facts $nfacts) lost=$(length(lost)) (facts $(count(ci -> ci.owner === :facts, lost))) ",
            "render_warm=$(round(t1 * 1e3; digits = 2))ms provider_load+first=$(round(tl; digits = 3))s render_after=$(round(t2 * 1e3; digits = 2))ms (compile $(round(c2 * 1e3; digits = 2))ms)")
    for ci in lost[1:min(end, 8)]
        mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
        println("X   lost ", ci.owner, " ", mi.specTypes)
    end
elseif CASE == "handover"
    KIND == "trait" || error("handover: trait only")
    const FORM = Symbol(get(ENV, "X7_FORM", "direct"))
    @eval module OldStyle
    const FORM = $(QuoteNode(FORM))
    # an old-style plot in a plain module: attributes in a Dict{Symbol, Any}, as upstream's old recipes keep them
    using TraitWorld
    import TraitMakie
    using TraitMakie.PlotCore: Plot, Canvas, Transform2D, ColorSpec, Bars, Positions, NOPOINTS
    import TraitMakie.PlotCore: datalimits, draw!, setcolor!
    "The old machinery's own helpers: plain functions over untyped attributes."
    function old_bins(a::Dict{Symbol,Any})
        v = a[:values]; bins = a[:bins]
        lo, hi = extrema(v)
        w = hi > lo ? (hi - lo) / bins : 1.0
        counts = zeros(bins)
        for x in v
            counts[clamp(floor(Int, (x - lo) / w) + 1, 1, bins)] += 1
        end
        return [lo + (k - 0.5) * w for k in 1:bins], counts, w
    end
    old_limits(a::Dict{Symbol,Any}) = (c = old_bins(a); (c[1][1] - c[3] / 2, c[1][end] + c[3] / 2, 0.0, maximum(c[2])))
    function old_bars!(b::Bars, a::Dict{Symbol,Any})
        xs, ys, w = old_bins(a)
        b.pos = Dynamic{Positions}(hcat(xs, ys))
        b.width = w
        return b
    end
    # only the session's form is declared: checking a declaration infers its operations (by facts), which
    # would compile the helpers whatever the render does
    if FORM === :direct
        # direct: the trait's operations call the helpers
        mutable struct OldHist
            attrs::Dict{Symbol,Any}
            bars::Bars
        end
        datalimits(h::OldHist) = old_limits(h.attrs)::NTuple{4,Float64}   # the declared result, asserted: the helpers are untyped
        draw!(h::OldHist, c::Canvas, t::Transform2D) = draw!(old_bars!(h.bars, h.attrs), c, t)
        setcolor!(h::OldHist, c::Kept{ColorSpec}) = (h.bars.color = c; nothing)
        Core.eval(@__MODULE__, :(@implement Plot OldHist))     # after the type exists: the macro reads it
    else
        # the hand-over: the operations call `Dynamic{Callable}`s that the old machinery registers, closures over its own code
        mutable struct OldHistH
            lim::Dynamic{Callable{Tuple{},NTuple{4,Float64}}}
            drw::Dynamic{Callable{Tuple{Canvas,Transform2D},Nothing}}
            bars::Bars
        end
        datalimits(h::OldHistH) = h.lim()
        draw!(h::OldHistH, c::Canvas, t::Transform2D) = h.drw(c, t)
        setcolor!(h::OldHistH, c::Kept{ColorSpec}) = (h.bars.color = c; nothing)
        Core.eval(@__MODULE__, :(@implement Plot OldHistH))
    end
    function make(form::Symbol, values::Vector{Float64}, bins::Int)
        a = Dict{Symbol,Any}(:values => values, :bins => bins)
        c = Dynamic{ColorSpec}(:green)
        b = Bars(Dynamic{Positions}(NOPOINTS), c, 1.0)
        form === :direct && return Base.invokelatest(OldHist, a, b)
        return Base.invokelatest(OldHistH, Dynamic{Callable{Tuple{},NTuple{4,Float64}}}(() -> old_limits(a)),
                        Dynamic{Callable{Tuple{Canvas,Transform2D},Nothing}}((cv, t) -> (draw!(old_bars!(b, a), cv, t); nothing)), b)
    end
    end
    for form in (Symbol(get(ENV, "X7_FORM", "direct")),)
        fig = PL.figure(; title = "x7")
        PL.lines!(fig, [1.0, 2.0, 3.0], [-1.0, 0.0, 1.0])
        nf0 = count(ci -> ci.owner === :facts, cis((OldStyle,)))
        PL.plot!(fig, Dynamic{TraitMakie.PlotCore.Plot}(OldStyle.make(form, DATA, 12)))
        nf1 = count(ci -> ci.owner === :facts, cis((OldStyle,)))
        println("X   facts CodeInstances in OldStyle: after the declaration $nf0, after the plot was made $nf1")
        c = ctime()
        PL.save(out("handover-$form"), fig)
        c1 = ctime() - c
        s = cis((OldStyle,))
        facts = [ci for ci in s if ci.owner === :facts]
        nm(ci) = string((ci.def isa Core.MethodInstance ? ci.def : ci.def.def).def.name)
        names = sort!(unique([nm(ci) for ci in facts]))
        plainnames = sort!(unique([nm(ci) for ci in s if ci.owner === nothing]))
        for ci in s
            n = nm(ci)
            (startswith(n, "#make") || startswith(n, "old_")) || continue
            println("X   ", rpad(n, 14), " owner=", rpad(string(ci.owner), 8), " native=", ci.invoke != C_NULL, " inferred=", isdefined(ci, :inferred) && ci.inferred !== nothing)
        end
        println("X kind=trait case=handover form=$form first_render_compile=$(round(c1 * 1e3; digits = 1))ms OldStyle_cis=$(length(s)) facts=$(length(facts)) facts_methods=$(join(names, ",")) plain_methods=$(join(plainnames, ","))")
    end
elseif CASE == "cost"
    hist2!(PL.figure(), DATA; bins = 12)                    # the provider loaded, its code compiled
    m = LOADED[]
    small = [1.0, 2.0, 3.0]
    stub() = (fig = PL.figure(); hist2!(fig, small; bins = 2); fig)
    direct() = (fig = PL.figure(); Base.invokelatest(m.hist2!, fig, small; bins = 2); fig)   # the provider's function, latest world
    plain_call() = (fig = PL.figure(); m.hist2!(fig, small; bins = 2); fig)
    for f in (stub, direct, plain_call); f(); f(); end
    t(f) = minimum(@elapsed(for _ in 1:1000; f(); end) for _ in 1:20) / 1000 * 1e9
    fig = PL.figure(); PL.lines!(fig, small, small)
    e_direct() = PL.save(out("cost"), fig)
    e_latest() = Base.invokelatest(PL.save, out("cost"), fig)
    e_direct(); e_latest()
    te(f) = minimum(@elapsed(for _ in 1:50; f(); end) for _ in 1:5) / 50 * 1e6
    println("X kind=$KIND case=cost stub=$(round(t(stub); digits = 1))ns via_invokelatest=$(round(t(direct); digits = 1))ns plain_call=$(round(t(plain_call); digits = 1))ns ",
            "save_direct=$(round(te(e_direct); digits = 1))us save_latest=$(round(te(e_latest); digits = 1))us")
end
