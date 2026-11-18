# E-359 (W-134 (d), E-110's form): a REPL row per demonstrator on the unified build.
#     julia --project=env_demo repl.jl D|T|Tp <csv> <outdir>
# After the session's work has run twice: a new type, a new closure, an edit. At each step: its time and compile
# time, first and again; the valid own instances it ends; the own instances it compiles, by package.
const kind, csv, out = ARGS[1:3]
const G2, FACTS = 0x10, 0x20
const sys = Set(nameof(Base.moduleroot(m)) for m in values(Base.loaded_modules))
include("demo_session.jl")
const ROOTS = Set(nameof(Base.moduleroot(m)) for m in values(Base.loaded_modules) if !(nameof(Base.moduleroot(m)) in sys))
function tally()
    res = Tuple{Symbol,Core.CodeInstance}[]
    Base.visit(Core.methodtable) do m
        r = nameof(Base.moduleroot(m.module)); r in ROOTS || return
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                ci.max_world == typemax(UInt) && ci.owner === nothing && push!(res, (r, ci))
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    return res
end
ms(t) = string(round(1000t; digits = 1), " ms")
timed(f) = (c0 = Base.cumulative_compile_time_ns(); t = @elapsed (d = Base.invokelatest(f)); c1 = Base.cumulative_compile_time_ns();
            (d, t, (c1[1] - c0[1]) / 1e9, (c1[2] - c0[2]) / 1e9))
bycount(v) = (by = Dict{Symbol,Int}(); for (r, _) in v; by[r] = get(by, r, 0) + 1; end;
              isempty(by) ? "" : "  [" * join(["$r $k" for (r, k) in sort(collect(by); by = last, rev = true)], ", ") * "]")
const SHOW = parse(Int, get(ENV, "SHOW", "6"))
# `prep` runs untimed (definitions, the edit); `f` is the step.
function step(label, f; prep = () -> nothing)
    before = tally()
    tp = @elapsed Base.invokelatest(prep)
    lostp = [(r, ci) for (r, ci) in before if ci.max_world != typemax(UInt)]
    r1 = timed(f); r2 = timed(f)
    after = tally(); seen = IdSet{Any}(ci for (_, ci) in before)
    lost = [(r, ci) for (r, ci) in before if ci.max_world != typemax(UInt)]
    made = [(r, ci) for (r, ci) in after if !(ci in seen)]
    println(rpad(label, 28), " first ", ms(r1[2]), " (compile ", ms(r1[3]), ", recompile ", ms(r1[4]), "), again ", ms(r2[2]),
            " | defining ", ms(tp), " | ended ", length(lostp), " by the definition, ", length(lost), " at the end (facts ",
            count(x -> (x[2].flags & FACTS) != 0, lost), ")", bycount(lost),
            " | compiled own ", length(made), " (facts ", count(x -> (x[2].flags & FACTS) != 0, made), ")", bycount(made))
    for (r, ci) in lost[1:min(end, SHOW)]; println("    ended:    ", (ci.flags & FACTS) != 0 ? "facts " : "plain ", ci.def.specTypes); end
    for (r, ci) in made[1:min(end, SHOW)]; println("    compiled: ", (ci.flags & FACTS) != 0 ? "facts " : "plain ", ci.def.specTypes); end
    return r1[1]
end
# The definitions of function `name` in `file`, as written (an edit evaluates them again).
function defs(file, name)
    res = Expr[]
    callname(x) = x isa Expr && x.head in (:where, :(::)) ? callname(x.args[1]) : x isa Expr && x.head === :call ? x.args[1] : nothing
    function walk(ex)
        ex isa Expr || return
        if ex.head in (:toplevel, :block); foreach(walk, ex.args)
        elseif ex.head === :module; walk(ex.args[3])
        elseif ex.head === :macrocall && ex.args[1] isa GlobalRef && ex.args[1].name === Symbol("@doc"); walk(ex.args[end])
        elseif ex.head === :function || (ex.head === :(=) && callname(ex.args[1]) !== nothing)
            callname(ex.args[1]) === name && push!(res, ex)
        end
    end
    walk(Meta.parseall(read(file, String); filename = file))
    return res
end
edit(mod, file, name) = (d = defs(file, name); @assert !isempty(d); for ex in d; Core.eval(mod, ex); end; length(d))

Base.cumulative_compile_timing(true)
println("kind ", kind, " | import ", ms(t0), " | roots ", length(ROOTS), " | own instances ", length(tally()))
step("the work", w)
if kind in ("T", "Tp")
    if kind == "T"
        @eval using TraitWorld
        @eval import TraitTables.TableCore: Column, nrows, cell
        tbl(ps...) = TB.table(ps...)
        defrep() = Core.eval(Main, quote
            struct Rep{T}; x::T; n::Int; end
            Base.eltype(::Type{Rep{T}}) where {T} = T
            @implement Column{T} Rep{T} where {T} begin
                nrows(c) = c.n
                cell(c, i) = c.x
            end
        end)
        emod() = TB.TableCore; efile() = joinpath(dirname(pathof(TB)), "TableCore.jl")
    else
        tbl(ps...) = TB.table(ps...)
        defrep() = Core.eval(Main, quote
            struct Rep{T} <: AbstractVector{T}; x::T; n::Int; end
            Base.size(c::Rep) = (c.n,)
            Base.getindex(c::Rep, i::Int) = c.x
        end)
        emod() = TB; efile() = pathof(TB)
    end
    use(t, name) = (s = TB.summary_text(t); h = TB.head(TB.sortby(t, name), 5); x = TB.floats(t, name);
                    f = PL.hist(x; bins = 12); PL.save(joinpath(out, "r.png"), f); string(hash((s, sum(x), TB.nrow(h))); base = 16))
    step("a new cell type (Int32)", () -> use(tbl("a" => Int32.(1:500), "b" => Float32.(1:500) ./ 7), "a"))
    step("a new column struct", () -> use(tbl("a" => collect(1.0:500.0), "r" => Main.Rep(2.5, 500)), "a"); prep = defrep)
    d1 = step("the work, before the edit", w)
    d2 = step("an edit of `summarize`", w; prep = () -> println("    methods evaluated again: ", edit(emod(), efile(), :summarize)))
    step("the same edit again", w; prep = () -> edit(emod(), efile(), :summarize))
    println("digest ", d1, d1 == d2 ? " (equal after the edit)" : " DIFFERS: $d2")
else
    vdp!(du, u, p, t) = (du[1] = u[2]; du[2] = p[1] * (1 - u[1]^2) * u[2] - u[1]; nothing)
    run(f, u0, p) = (s = ODE.solve(ODE.ODEProblem(f, u0, (0.0, 10.0), p), ODE.Tsit5(); saveat = collect(range(0.0, 10.0; length = 501)), reltol = 1e-6, abstol = 1e-8);
                     g = PL.lines(pts(s, 1)); PL.save(joinpath(out, "r.png"), g); string(hash(round.(comp(s, 1)[[100, 501]]; sigdigits = 6)); base = 16))
    step("a new closure (the RHS)", () -> run(vdp!, [2.0, 0.0], [1.0]))
    defp() = Core.eval(Main, quote
        struct LP; s::Float64; r::Float64; b::Float64; end
        lorenz_lp!(du, u, p, t) = (du[1] = p.s * (u[2] - u[1]); du[2] = u[1] * (p.r - u[3]) - u[2]; du[3] = u[1] * u[2] - p.b * u[3]; nothing)
    end)
    step("a new parameter struct", () -> run(Main.lorenz_lp!, [1.0, 0.0, 0.0], Main.LP(10.0, 28.0, 8 / 3)); prep = defp)
    d1 = step("the work, before the edit", w)
    file = joinpath(dirname(pathof(ODE.ODECore)), "core.jl")
    d2 = step("an edit of `save_step!`", w; prep = () -> println("    methods evaluated again: ", edit(ODE.ODECore, file, :save_step!)))
    step("the same edit again", w; prep = () -> edit(ODE.ODECore, file, :save_step!))
    step("an edit of `initdt`", w; prep = () -> edit(ODE.ODECore, file, :initdt))
    println("digest ", d1, d1 == d2 ? " (equal after the edit)" : " DIFFERS: $d2")
end
