# E-141: where TraitDifferentialEquations' first calls lose time under unrelated loads.
# TraitDifferentialEquations/scripts/rows.jl, rows 1 to 4, instrumented. Product setting.
#
#     JULIA_LOAD_PATH="<TDE scripts/env>:<TraitReport/env_loads>:@stdlib" \
#         julia --startup-file=no tde_diag.jl none|before|after <outprefix> [Pkg ...]
#
# The packages default to CSV DataFrames CairoMakie (the round's "big loads").
# Per row: wall time, @timed's compile and recompile time, GC time; the CodeInstances the row
# created, by owner and by module; how many of them replace an invalidated CodeInstance of the
# same MethodInstance and owner ("again"); the list of them, to <outprefix>.row<k>.cis.
# Around the loads and `using TraitDifferentialEquations`: the invalidation logs (method table and
# image validation), summarized, to <outprefix>.inv.  A compile trace with times goes to stderr,
# with "#### row k" markers.
const MODE = ARGS[1]
const OUT = ARGS[2]
const PKGS = length(ARGS) > 2 ? ARGS[3:end] : ["CSV", "DataFrames", "CairoMakie"]
const RU = Base.Compiler.ReinferUtils
# PROFROW=k: profile row k (the outer window), flat with C frames, to <outprefix>.row<k>.prof
const PROFROW = parse(Int, get(ENV, "PROFROW", "0"))
using Profile
PROFROW > 0 && Profile.init(n = 10^7, delay = parse(Float64, get(ENV, "PROFDELAY", "0.0005")))

# --- snapshots of the method caches -------------------------------------------------------------
function snapshot()
    valid = Set{Core.CodeInstance}(); invalid = Set{Tuple{Core.MethodInstance,Any}}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                if ci.max_world == typemax(UInt)
                    push!(valid, ci)
                else
                    push!(invalid, (mi, ci.owner))
                end
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    return valid, invalid
end
mi_of(ci) = (d = ci.def; d isa Core.MethodInstance ? d : d.def)
function root(ci)
    m = mi_of(ci).def
    m isa Method ? nameof(Base.moduleroot(m.module)) : :toplevel
end
owner_s(o) = o === nothing ? "nothing" : repr(o)
tally(f, xs) = (d = Dict{Any,Int}(); for x in xs; k = f(x); d[k] = get(d, k, 0) + 1; end; sort!(collect(d); by = x -> -last(x)))
fmt(ps; n = 12) = join(["$(k)=$(v)" for (k, v) in ps[1:min(end, n)]], " ")

snapshot()  # compile the snapshot code before any measurement
const ROWK = Ref(0)
const STATE = Ref{Any}(nothing)
const T0 = Ref(UInt64(0)); const C0 = Ref((UInt64(0), UInt64(0))); const G0 = Ref{Any}(nothing)
# Two windows. "inner" is rows.jl's number: `@elapsed` forces the top-level statement to be
# compiled, so the inference that compiling the statement does (the call at its concrete types,
# and all it reaches statically) happens before its clock starts. "outer" also counts that: from
# before the statement is compiled to after it ran. The snapshot is outside both.
function pre(n, what)
    ROWK[] += 1
    STATE[] = snapshot()
    println(stderr, "#### row $(ROWK[]) $n $what"); flush(stderr)
    Base.cumulative_compile_timing(true)
    C0[] = Base.cumulative_compile_time_ns()
    ccall(:jl_force_trace_compile_timing_enable, Cvoid, ())
    ROWK[] == PROFROW && Profile.start_timer()
    G0[] = Base.gc_num()
    T0[] = time_ns()
    nothing
end
function post(n, what, @nospecialize(st))
    t1 = time_ns(); g1 = Base.gc_num()
    if ROWK[] == PROFROW
        Profile.stop_timer()
        open(io -> Profile.print(IOContext(io, :displaysize => (100000, 400)); format = :flat, sortedby = :count, C = true, mincount = 3), "$OUT.row$(ROWK[]).prof", "w")
        open(io -> Profile.print(IOContext(io, :displaysize => (100000, 400)); format = :tree, C = false, mincount = 5, maxdepth = 60), "$OUT.row$(ROWK[]).tree", "w")
    end
    ccall(:jl_force_trace_compile_timing_disable, Cvoid, ())
    c1 = Base.cumulative_compile_time_ns()
    Base.cumulative_compile_timing(false)
    k = ROWK[]; v0, inv0 = STATE[]
    v1, _ = snapshot()
    new = collect(setdiff(v1, v0))
    again = [ci for ci in new if (mi_of(ci), ci.owner) in inv0]
    println("row ", n, " ", what, " ", round(1000st.time; digits = 1), " ms",
            "  [inner: compile ", round(1000st.compile_time; digits = 1), " recompile ", round(1000st.recompile_time; digits = 1),
            " gc ", round(1000st.gctime; digits = 1), " | outer ", round((t1 - T0[]) / 1e6; digits = 1), " ms, compile ",
            round((c1[1] - C0[][1]) / 1e6; digits = 1), " recompile ", round((c1[2] - C0[][2]) / 1e6; digits = 1),
            " gc ", round(Base.GC_Diff(g1, G0[]).total_time / 1e6; digits = 1),
            " | new CIs ", length(new), " again ", length(again), "]")
    println("    by owner: ", fmt(tally(ci -> owner_s(ci.owner), new)))
    println("    by module: ", fmt(tally(root, new)))
    isempty(again) || println("    again by module: ", fmt(tally(ci -> (root(ci), owner_s(ci.owner)), again)))
    open("$OUT.row$k.cis", "w") do io
        for ci in sort!(new; by = ci -> string(mi_of(ci).specTypes))
            println(io, owner_s(ci.owner), "\t", (mi_of(ci), ci.owner) in inv0 ? "again" : "new", "\t", root(ci), "\t", mi_of(ci).specTypes)
        end
    end
    flush(stdout)
    nothing
end
# Three top-level statements. The measured one has rows.jl's shape, `row(n, what, @elapsed ex)`:
# a call (so the statement is compiled, not interpreted; a `global` assignment would make it
# interpreted) whose argument is `@elapsed`'s block (forced compilation), with the compile-time
# counters read next to the clock.
const ST = Ref{Any}(nothing)
rec(x) = (ST[] = x; nothing)
macro measure(n, what, ex)
    Expr(:toplevel, :(pre($n, $what)),
         :(rec(begin
               Base.Experimental.@force_compile
               local c0 = Base.cumulative_compile_time_ns(); local g0 = Base.gc_num(); local t0 = time_ns()
               $(esc(ex))
               local t1 = time_ns(); local c1 = Base.cumulative_compile_time_ns(); local g1 = Base.gc_num()
               (time = (t1 - t0) / 1e9, compile_time = (c1[1] - c0[1]) / 1e9, recompile_time = (c1[2] - c0[2]) / 1e9,
                gctime = Base.GC_Diff(g1, g0).total_time / 1e9)
           end)),
         :(post($n, $what, ST[])))
end
# compile pre, post and the macro's shape once, outside any row
@measure 0 "warm-up" sum([1, 2])
ROWK[] = 0

# --- invalidation logging around loads ------------------------------------------------------------
function logged(f, label)
    le = RU.debug_method_invalidation(true)
    lm = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
    v0, _ = snapshot()
    t = @elapsed try f() finally
        RU.debug_method_invalidation(false); ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
    end
    Base.invokelatest(report_loads, label, t, v0, le, lm)
end
function report_loads(label, t, v0, le, lm)
    v1, _ = snapshot()
    lost = [ci for ci in v0 if ci.max_world != typemax(UInt)]
    println(label, " ", round(t; digits = 2), " s; valid CIs before ", length(v0), ", lost ", length(lost),
            " (by owner: ", fmt(tally(ci -> owner_s(ci.owner), lost)), ")")
    println("    lost by module: ", fmt(tally(ci -> (root(ci), owner_s(ci.owner)), lost); n = 20))
    # image validation: entries (item, tag, codeinst, cause) in the edges log
    tags = tally(x -> x, filter(x -> x isa String, le))
    println("    image-validation log: ", length(le), " entries; tags ", fmt(tags))
    open("$OUT.inv", "a") do io
        println(io, "=== ", label)
        println(io, "--- lost (valid before, invalid after)")
        for ci in sort!(lost; by = ci -> string(mi_of(ci).specTypes))
            println(io, owner_s(ci.owner), "\t", root(ci), "\t", mi_of(ci).specTypes)
        end
        println(io, "--- image validation log")
        i = 1
        while i <= length(le)
            x = le[i]
            if i + 1 <= length(le) && le[i+1] isa String
                tag = le[i+1]
                ci = i + 2 <= length(le) ? le[i+2] : nothing
                s = ci isa Core.CodeInstance ? owner_s(ci.owner) * "\t" * string(root(ci)) * "\t" * string(mi_of(ci).specTypes) : repr(ci)
                println(io, tag, "\t", x isa Core.CodeInstance ? "CI " * string(mi_of(x).specTypes) : first(repr(x), 200), "\t=> ", s)
                i += tag == "verify_methods" ? 3 : 4
            else
                i += 1
            end
        end
        println(io, "--- image validation: root causes (edges with new matches) of each rejected CodeInstance")
        cause = IdDict{Any,Any}(); roots = IdDict{Any,Vector{Any}}()
        i = 1
        while i <= length(le)
            if i + 1 <= length(le) && le[i+1] == "verify_methods"
                cause[le[i]] = le[i+2]; i += 3
            elseif i + 1 <= length(le) && le[i+1] == "insert_backedges_callee"
                push!(get!(roots, le[i+2], Any[]), (le[i], le[i+3])); i += 4
            elseif i + 1 <= length(le) && le[i+1] == "method_globalref"
                push!(get!(roots, le[i+2], Any[]), (le[i], "globalref")); i += 4
            else
                i += 1
            end
        end
        shs(x) = x isa Core.CodeInstance ? string(mi_of(x).specTypes) : x isa Method ? string(x.module, ".", x.name, " ", x.sig) : first(string(x), 200)
        function rootof(c)
            seen = IdSet{Any}()
            while haskey(cause, c) && cause[c] !== c && !(c in seen)
                push!(seen, c); c = cause[c]
            end
            c
        end
        for c in keys(cause)
            r = rootof(c)
            rs = get(roots, r, Any[])
            println(io, "REJECTED ", owner_s(c.owner), "\t", root(c), "\t", shs(c), "\n    via ", shs(r))
            for (edge, ms) in rs
                println(io, "    edge ", shs(edge), "  new matches: ", ms isa Vector ? join([m isa Core.MethodMatch ? shs(m.method) : m isa Method ? shs(m) : first(repr(m), 120) for m in ms], " | ") : ms)
            end
        end
        println(io, "--- method-table log, raw")
        for x in lm
            println(io, x isa Core.MethodInstance ? "MI " * string(x.specTypes) : x isa Core.CodeInstance ? "CI " * owner_s(x.owner) * " " * string(mi_of(x).specTypes) : x isa Method ? "METHOD " * shs(x) : first(repr(x), 200))
        end
        println(io, "--- method-table log: winning methods with invalidations")
        nmi = 0; causes = Dict{Any,Int}()
        for (j, x) in enumerate(lm)
            if x isa Core.MethodInstance
                nmi += 1
            elseif x isa Method && j < length(lm) && lm[j+1] == "jl_method_table_insert"
                causes[x] = get(causes, x, 0) + nmi; nmi = 0
            end
        end
        for (m, c) in sort!(collect(causes); by = x -> -last(x))
            c > 0 && println(io, lpad(c, 6), "  ", m.module, ".", m.name, "  ", m.sig)
        end
    end
    v1
end

load_big() = logged(() -> (for p in PKGS; Core.eval(Main, Meta.parse("using $p")); end), "loads " * join(PKGS, ","))

isfile("$OUT.inv") && rm("$OUT.inv")
println("mode ", MODE, " loads ", join(PKGS, " "), "  facts=", Base.Compiler.NativeInterpreter().facts)
MODE == "before" && load_big()
logged(() -> (@eval Main using TraitDifferentialEquations, TraitWorld), "using TraitDifferentialEquations")

lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
const U0, P0 = [1.0, 0.0, 0.0], [10.0, 28.0, 8 / 3]
@measure 1 "first Tsit5 solve, a plain function" solve(ODEProblem(lorenz!, U0, (0.0, 1.0), P0), Tsit5())
MODE == "after" && load_big()

rossler!(du, u, p, t) = (du[1] = -u[2] - u[3]; du[2] = u[1] + p[1] * u[2]; du[3] = p[2] + u[3] * (u[1] - p[3]); nothing)
@measure 2 "a second model function" solve(ODEProblem(rossler!, U0, (0.0, 1.0), [0.2, 0.2, 5.7]), Tsit5())

@eval struct Lorenz; s::Float64; r::Float64; b::Float64; end
@eval TraitDifferentialEquations.rhs!(m::Lorenz, du::Vector{Float64}, u::Vector{Float64}, t::Float64) =
    (du[1] = m.s * (u[2] - u[1]); du[2] = u[1] * (m.r - u[3]) - u[2]; du[3] = u[1] * u[2] - m.b * u[3]; nothing)
@measure 2 "a new model type: @implement" @eval @implement ODEModel{Float64} Lorenz
@measure 2 "a new model type: first solve" solve(Lorenz(10.0, 28.0, 8 / 3), U0, (0.0, 1.0), Tsit5())

@measure 3 "first Rodas5 solve" solve(ODEProblem(lorenz!, U0, (0.0, 1.0), P0), Rodas5())

kick = DiscreteCallback((u, t, i) -> t > 0.5 && t < 0.6, i -> (i.u[1] += 1.0; nothing))
@measure 4 "a new callback closure" solve(ODEProblem(lorenz!, U0, (0.0, 1.0), P0), Tsit5(); callback = kick)
stop = DiscreteCallback((u, t, i) -> u[1] > 5.0, i -> (i.terminated = true; nothing))
@measure 4 "a second callback closure" solve(ODEProblem(lorenz!, U0, (0.0, 1.0), P0), Tsit5(); callback = stop)
