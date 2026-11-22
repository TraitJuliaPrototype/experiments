# W-19, second part: what plain code pays with the facts mode off. Upstream CSV and DataFrames, compiled plainly
# (envs/up); no module declares an option. Counts of the session's valid CodeInstances (owner nothing) after the
# load and after the first work, how many record the facts policy (0x20) or carry G2 (0x10), the first work's time
# and compile time, and the work's result digest.
#     julia --project=envs/up f-plain.jl <csv>
const csv = ARGS[1]
r(x) = round(1000x; digits = 1)
function tally()
    n = 0; f = 0; g = 0
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                if ci.owner === nothing && ci.max_world == typemax(UInt)
                    n += 1; (ci.flags & 0x20) != 0 && (f += 1); (ci.flags & 0x10) != 0 && (g += 1)
                end
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    return n, f, g
end
t0 = @elapsed @eval using CSV, DataFrames
n0 = tally()
w = @eval () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                 g = combine(groupby(df, names(df)[end]), c => sum); string(hash(repr((d, first(s, 3), g))); base = 16))
Base.cumulative_compile_timing(true); c0 = Base.cumulative_compile_time_ns()
t1 = @elapsed (d = Base.invokelatest(w))
c1 = Base.cumulative_compile_time_ns(); Base.cumulative_compile_timing(false)
t2 = @elapsed Base.invokelatest(w)
n1 = tally()
println("load ", r(t0), " ms | CodeInstances after the load ", n0[1], " (facts ", n0[2], ", G2 ", n0[3], ") | first work ", r(t1),
        " ms, compile ", r((c1[1] - c0[1]) / 1e9), " ms, again ", r(t2), " ms | after the work ", n1[1], " (facts ", n1[2], ", G2 ", n1[3], ") | digest ", d)
