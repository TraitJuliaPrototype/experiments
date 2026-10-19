# Step 0: what upstream CSV + DataFrames pay after the nine loads (control/lost.jl's work), in full.
#     julia [-J facts/sys.so] afterloads.jl <csv> <package>...
# 1. the work twice; 2. the loads with invalidation logging (the winning methods, Base included);
# 3. valid CodeInstances of every module before and after; 4. the work again under @timed
#    (compile and recompile time) with a compile trace (stderr, `#= ms =# precompile(...)`).
const csv = ARGS[1]; pk = ARGS[2:end]
using CSV, DataFrames, InteractiveUtils
get(ENV, "PRELOAD", "") == "" || Core.eval(Main, Meta.parse("using " * ENV["PRELOAD"]))  # loaded before the work (an interactive session has REPL)
println("mode: ", Base.Compiler.NativeInterpreter().facts ? "all (facts)" : "plain")
function snapshot()
    s = Set{Core.CodeInstance}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                ci.max_world == typemax(UInt) && push!(s, ci)
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    s
end
root(ci) = (d = ci.def; mi = d isa Core.MethodInstance ? d : d.def; m = mi.def; m isa Method ? nameof(Base.moduleroot(m.module)) : :toplevel)
byowner(cis) = (d = Dict{Any,Int}(); for ci in cis; d[ci.owner] = get(d, ci.owner, 0) + 1; end; sort!(collect(d); by = x -> -last(x)))
bymod(cis) = (d = Dict{Symbol,Int}(); for ci in cis; r = root(ci); d[r] = get(d, r, 0) + 1; end; sort!(collect(d); by = x -> -last(x)))
w = @eval () -> (df = CSV.read($csv, DataFrame); describe(df); c = names(df)[1]; sort(df, c); combine(groupby(df, names(df)[end]), c => sum); nothing)
t1 = @elapsed Base.invokelatest(w); t1b = @elapsed Base.invokelatest(w)
println("work: first ", round(1000t1; digits = 1), " ms, again ", round(1000t1b; digits = 1), " ms")
before = snapshot()
invs = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
for p in pk; Core.eval(Main, Meta.parse("using $p")); end
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
mid = snapshot()
lost = [ci for ci in before if ci.max_world != typemax(UInt)]
println("valid before the loads: ", length(before), "; lost by the loads: ", length(lost))
println("lost by module: ", bymod(lost))
println("lost by owner: ", byowner(lost))
# Causes: in the log, a Method followed by "jl_method_table_insert" is a winning method; the entries
# before it (back to the previous cause) are what it invalidated.
causes = Dict{Any,Int}(); n = 0
for (i, x) in enumerate(invs)
    if x isa Core.MethodInstance; global n += 1
    elseif x isa Method && i < length(invs) && invs[i+1] == "jl_method_table_insert"; causes[x] = get(causes, x, 0) + n; global n = 0
    elseif x isa String && x != "jl_method_table_insert" && startswith(x, "jl_")  # other tags
    end
end
println("invalidation log entries: ", length(invs), "; winning methods with invalidations: ", count(>(0), values(causes)))
for (m, k) in sort!(collect(causes); by = x -> -last(x))[1:min(end, 40)]
    k > 0 && println("  ", lpad(k, 5), "  ", m.module, ".", m.name, "  ", m.sig, "  ", m.file, ":", m.line)
end
flush(stdout)
Base.cumulative_compile_timing(true)
c0 = Base.cumulative_compile_time_ns()
ccall(:jl_force_trace_compile_timing_enable, Cvoid, ())
t2 = @elapsed Base.invokelatest(w)
ccall(:jl_force_trace_compile_timing_disable, Cvoid, ())
c1 = Base.cumulative_compile_time_ns()
Base.cumulative_compile_timing(false)
after = snapshot()
new = setdiff(after, mid)
println("work after the loads: ", round(1000t2; digits = 1), " ms; compile ", round((c1[1] - c0[1]) / 1e6; digits = 1), " ms, of it recompile ", round((c1[2] - c0[2]) / 1e6; digits = 1), " ms")
println("new CodeInstances in the work after the loads: ", length(new), "  ", bymod(new))
println("  by owner: ", byowner(new))
mi(ci) = (d = ci.def; d isa Core.MethodInstance ? d : d.def)
lostmis = Set(mi(ci) for ci in lost)
again = [ci for ci in new if mi(ci) in lostmis]
println("  of them again for a lost MethodInstance: ", length(again), "  ", bymod(again))
println("  the rest, new specializations: ", length(new) - length(again), "  ", bymod(setdiff(new, again)))
for ci in sort!(collect(setdiff(new, again)); by = ci -> string(mi(ci).specTypes))[1:min(end, 60)]
    println("    ", root(ci), "  ", mi(ci).specTypes, ci.owner === nothing ? "" : "  owner=" * repr(ci.owner))
end
