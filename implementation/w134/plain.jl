# E-356 (W-134 (b)): what a session of plain Julia pays. Upstream CSV and DataFrames, compiled plainly.
#     julia --project=env_up  plain.jl <csv> none        vanilla or unified, no library
#     julia --project=env_lib plain.jl <csv> first       the library loaded before the packages
#     julia --project=env_lib plain.jl <csv> late        the library loaded after the work; what its load ends
const csv = ARGS[1]; const mode = ARGS[2]
r(x) = round(1000x; digits = 2)
using Statistics
mode == "first" && println("using TraitWorld ", r(@elapsed @eval using TraitWorld), " ms")
println("using CSV, DataFrames ", r(@elapsed @eval using CSV, DataFrames), " ms")
w = @eval () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                 g = combine(groupby(df, names(df)[end]), c => sum); nothing)
function timed(f)
    Base.cumulative_compile_timing(true); c0 = Base.cumulative_compile_time_ns()
    t = @elapsed Base.invokelatest(f)
    c1 = Base.cumulative_compile_time_ns(); Base.cumulative_compile_timing(false)
    return t, (c1[1] - c0[1]) / 1e9
end
reps(f, n) = (f(); ts = [(@elapsed f()) for _ in 1:n]; (median(ts), minimum(ts)))
t, c = timed(w); println("first work ", r(t), " ms, compile ", r(c), " ms")
m, l = Base.invokelatest(reps, w, 200); println("repeated: median ", r(m), " ms, least ", r(l), " ms")
if mode == "late"
    valid() = (s = IdSet{Any}(); Base.visit(Core.methodtable) do meth
            for mi in Base.specializations(meth)
                mi isa Core.MethodInstance || continue
                ci = isdefined(mi, :cache) ? mi.cache : nothing
                while ci !== nothing
                    ci.owner === nothing && ci.max_world == typemax(UInt) && push!(s, ci)
                    ci = isdefined(ci, :next) ? ci.next : nothing
                end
            end
        end; s)
    before = valid()
    println("using TraitWorld (late) ", r(@elapsed @eval using TraitWorld), " ms")
    lost = [ci for ci in before if ci.max_world != typemax(UInt)]
    by = Dict{Symbol,Int}()
    for ci in lost; d = ci.def.def; k = d isa Method ? nameof(Base.moduleroot(d.module)) : :toplevel; by[k] = get(by, k, 0) + 1; end
    println("ended by the library's load: ", length(lost), " of ", length(before), " | ", join(["$k $n" for (k, n) in sort(collect(by); by = last, rev = true)], ", "))
    for ci in lost[1:min(end, 12)]; println("  ", ci.def.specTypes); end
    t, c = timed(w); println("work after the library's load ", r(t), " ms, compile ", r(c), " ms")
    m, l = Base.invokelatest(reps, w, 200); println("repeated after: median ", r(m), " ms, least ", r(l), " ms")
end
