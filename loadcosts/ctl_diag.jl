# E-142: what upstream CSV + DataFrames pay after nine unrelated loads under the test bed `all`
# (experiments/factscompiler/control/lost.jl's "upstream" work, the round's 435 ms).
#
#     julia -J facts/sys.so ctl_diag.jl <csv> <outprefix> <package>...
#
# Environment:
#   STEPS=1   after the loads, time the work's four steps one by one (CSV.read, describe, sort,
#             combine); otherwise the work as the control runs it, as one closure.
#   PROF=1    profile the work after the loads (C frames), flat, to <outprefix>.prof, and a
#             breakdown by interpreter (frames of PlainRTInterp: run-time `return_type`; of the
#             NativeInterpreter: compilation; LLVM; GC) to stdout.
#   TRACE=1   the compile trace with times, to stderr, during the work after the loads.
# Always: the loads' invalidations (method-table log), the valid CodeInstances lost by owner and
# module, the CodeInstances the work after the loads creates (by owner, module, "again" for a
# MethodInstance whose CodeInstance of that owner was lost), the compile and recompile time.
const csv = ARGS[1]; const OUT = ARGS[2]; const pk = ARGS[3:end]
using CSV, DataFrames
get(ENV, "PROF", "0") == "1" && using Profile
println("mode: ", Base.Compiler.NativeInterpreter().facts ? "all (facts)" : "plain", "; loads: ", join(pk, " "))

mi_of(ci) = (d = ci.def; d isa Core.MethodInstance ? d : d.def)
root(ci) = (m = mi_of(ci).def; m isa Method ? nameof(Base.moduleroot(m.module)) : :toplevel)
owner_s(o) = o === nothing ? "nothing" : repr(o)
tally(f, xs) = (d = Dict{Any,Int}(); for x in xs; k = f(x); d[k] = get(d, k, 0) + 1; end; sort!(collect(d); by = x -> -last(x)))
fmt(ps; n = 14) = join(["$(k)=$(v)" for (k, v) in ps[1:min(end, n)]], " ")
function snapshot()
    valid = Set{Core.CodeInstance}(); invalid = Set{Tuple{Core.MethodInstance,Any}}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                ci.max_world == typemax(UInt) ? push!(valid, ci) : push!(invalid, (mi, ci.owner))
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    return valid, invalid
end
snapshot()

const STEPS = [
    ("CSV.read", @eval () -> CSV.read($csv, DataFrame)),
    ("describe", df -> describe(df)),
    ("sort", df -> sort(df, names(df)[1])),
    ("combine", df -> combine(groupby(df, names(df)[end]), names(df)[1] => sum)),
]
w = @eval () -> (df = CSV.read($csv, DataFrame); describe(df); c = names(df)[1]; sort(df, c); combine(groupby(df, names(df)[end]), c => sum); nothing)
function steps_once()
    df = Base.invokelatest(STEPS[1][2])
    for (_, f) in STEPS[2:end]; Base.invokelatest(f, df); end
end
t1 = @elapsed Base.invokelatest(w); t1b = @elapsed Base.invokelatest(w)
steps_once(); steps_once()
println("work: first ", round(1000t1; digits = 1), " ms, again ", round(1000t1b; digits = 1), " ms")

v0, _ = snapshot()
lm = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
tl = @elapsed for p in pk; Core.eval(Main, Meta.parse("using $p")); end
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)

function report_loads(tl, v0, lm)
    v1, inv1 = snapshot()
    lost = [ci for ci in v0 if ci.max_world != typemax(UInt)]
    println("loads ", round(tl; digits = 2), " s; valid before ", length(v0), ", lost ", length(lost))
    println("  lost by owner: ", fmt(tally(ci -> owner_s(ci.owner), lost)))
    println("  lost by module and owner: ", fmt(tally(ci -> (root(ci), owner_s(ci.owner)), lost); n = 20))
    causes = Dict{Any,Int}(); n = 0
    for (j, x) in enumerate(lm)
        if x isa Core.MethodInstance || x isa Core.CodeInstance
            n += 1
        elseif x isa Method && j < length(lm) && lm[j+1] == "jl_method_table_insert"
            causes[x] = get(causes, x, 0) + n; n = 0
        end
    end
    open("$OUT.inv", "w") do io
        println(io, "--- lost (valid before the loads, invalid after)")
        for ci in sort!(lost; by = ci -> (owner_s(ci.owner), string(mi_of(ci).specTypes)))
            println(io, owner_s(ci.owner), "\t", root(ci), "\t", mi_of(ci).specTypes)
        end
        println(io, "--- winning methods, by entries invalidated")
        for (m, c) in sort!(collect(causes); by = x -> -last(x))
            c > 0 && println(io, lpad(c, 6), "  ", m.module, ".", m.name, "  ", m.sig, "  ", m.file, ":", m.line)
        end
        println(io, "--- method-table log, raw")
        for x in lm
            println(io, x isa Core.MethodInstance ? "MI " * string(x.specTypes) :
                        x isa Core.CodeInstance ? "CI " * owner_s(x.owner) * " " * string(mi_of(x).specTypes) :
                        x isa Method ? "METHOD " * string(x.module, ".", x.name, " ", x.sig) : first(repr(x), 200))
        end
    end
    return v1, inv1, lost
end
_, _, lost = Base.invokelatest(report_loads, tl, v0, lm)
flush(stdout)
v1, inv1 = snapshot()      # after the reports: what they compiled is not the work's

function measured(label, f, args...)
    Base.cumulative_compile_timing(true)
    c0 = Base.cumulative_compile_time_ns(); g0 = Base.gc_num()
    t = @elapsed (r = Base.invokelatest(f, args...))
    c1 = Base.cumulative_compile_time_ns(); g1 = Base.gc_num()
    Base.cumulative_compile_timing(false)
    println(label, ": ", round(1000t; digits = 1), " ms; compile ", round((c1[1] - c0[1]) / 1e6; digits = 1),
            " ms, of it recompile ", round((c1[2] - c0[2]) / 1e6; digits = 1), " ms; gc ", round(Base.GC_Diff(g1, g0).total_time / 1e6; digits = 1), " ms")
    return r
end
get(ENV, "PROF", "0") == "1" && Profile.init(n = 10^7, delay = 0.0005)
get(ENV, "TRACE", "0") == "1" && ccall(:jl_force_trace_compile_timing_enable, Cvoid, ())
get(ENV, "PROF", "0") == "1" && Profile.start_timer()
if get(ENV, "STEPS", "0") == "1"
    df = measured("after the loads, step CSV.read", STEPS[1][2])
    for (name, f) in STEPS[2:end]; measured("after the loads, step " * name, f, df); end
else
    measured("work after the loads", w)
end
get(ENV, "PROF", "0") == "1" && Profile.stop_timer()
get(ENV, "TRACE", "0") == "1" && ccall(:jl_force_trace_compile_timing_disable, Cvoid, ())
const V2 = snapshot()[1]      # right after the work, before any reporting compiles anything
measured("work again", w)

function report_new(v1, inv1, lost)
    new = collect(setdiff(V2, v1))
    lostk = Set((mi_of(ci), ci.owner) for ci in lost)
    again = [ci for ci in new if (mi_of(ci), ci.owner) in lostk || (mi_of(ci), ci.owner) in inv1]
    println("new CodeInstances in the work after the loads: ", length(new), "; again (their owner's CodeInstance was lost): ", length(again))
    println("  new by owner: ", fmt(tally(ci -> owner_s(ci.owner), new)))
    println("  again by owner: ", fmt(tally(ci -> owner_s(ci.owner), again)))
    println("  new, not again, by owner and module: ", fmt(tally(ci -> (owner_s(ci.owner), root(ci)), setdiff(new, again)); n = 20))
    println("  again by owner and module: ", fmt(tally(ci -> (owner_s(ci.owner), root(ci)), again); n = 20))
    open("$OUT.new", "w") do io
        for ci in sort!(new; by = ci -> (owner_s(ci.owner), string(mi_of(ci).specTypes)))
            println(io, owner_s(ci.owner), "\t", ci in again ? "again" : "new", "\t", root(ci), "\t", mi_of(ci).specTypes)
        end
    end
end
Base.invokelatest(report_new, v1, inv1, lost)

if get(ENV, "PROF", "0") == "1"
    open(io -> Profile.print(IOContext(io, :displaysize => (100000, 400)); format = :flat, sortedby = :count, C = true, mincount = 5), "$OUT.prof", "w")
    open(io -> Profile.print(IOContext(io, :displaysize => (100000, 300)); format = :tree, C = true, mincount = 8, noisefloor = 0), "$OUT.tree", "w")
    # per sample: which interpreter's frames it holds, and LLVM / GC
    data, ldict = Profile.retrieve()
    cat = Dict{String,Int}(); nsamp = 0
    function classify(frames)
        s = Set{String}()
        for fr in frames
            st = string(fr.func, " ", fr.file)
            sig = fr.linfo === nothing ? "" : string(fr.linfo)
            (occursin("PlainRTInterp", sig) || occursin("PlainRT", st)) && push!(s, "PlainRTInterp (run-time return_type)")
            (occursin("NativeInterpreter", sig)) && push!(s, "NativeInterpreter (compilation)")
            occursin("libLLVM", string(fr.file)) && push!(s, "LLVM")
            (occursin("gc", string(fr.func)) && occursin("gc", string(fr.file))) && push!(s, "GC")
            occursin("jl_matching_methods", string(fr.func)) && push!(s, "jl_matching_methods")
            occursin("return_type", string(fr.func)) && push!(s, "a return_type frame")
            occursin("typeinf", string(fr.func)) && push!(s, "a typeinf frame")
        end
        s
    end
    local i = 1; cur = UInt64[]
    # Profile data: blocks of instruction pointers ending in metadata and two zeros
    while i <= length(data)
        if data[i] == 0 && i < length(data) && data[i+1] == 0
            # end of a block: the last few words are metadata (thread, task, cpu, time); drop them
            ips = cur[1:max(0, end - Profile.nmeta)]
            frames = Profile.StackFrame[]
            for ip in ips
                haskey(ldict, ip) && append!(frames, ldict[ip])
            end
            if !isempty(frames)
                global nsamp += 1
                for c in classify(frames); cat[c] = get(cat, c, 0) + 1; end
            end
            empty!(cur); i += 2
        else
            push!(cur, data[i]); i += 1
        end
    end
    println("profile: ", nsamp, " samples")
    for (k, v) in sort!(collect(cat); by = x -> -last(x)); println("  ", lpad(v, 6), "  ", round(100v / max(nsamp, 1); digits = 1), "%  ", k); end
end
