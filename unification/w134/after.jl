# E-355, the follow-up: what does the work compile again after the loads? Order A of lost.jl, then the
# CodeInstances (any module, owner nothing) that the work after the loads makes, by root module, and
# the compile time inside it.
#     julia --project=env_* after.jl <csv> <package>...
const csv = ARGS[1]; const pk = ARGS[2:end]
const FACTS = 0x20
using CSV, DataFrames
function allcis()
    s = IdSet{Any}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci !== nothing
                ci.owner === nothing && ci.max_world == typemax(UInt) && push!(s, ci)
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    return s
end
w = @eval () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                 g = combine(groupby(df, names(df)[end]), c => sum); nothing)
function timed(f)
    Base.cumulative_compile_timing(true); c0 = Base.cumulative_compile_time_ns()
    t = @elapsed Base.invokelatest(f)
    c1 = Base.cumulative_compile_time_ns(); Base.cumulative_compile_timing(false)
    return t, (c1[1] - c0[1]) / 1e9, (c1[2] - c0[2]) / 1e9
end
r(x) = round(1000x; digits = 1)
t, c, rc = timed(w); println("first work ", r(t), " ms, compile ", r(c), " ms, of it recompile ", r(rc), " ms")
for p in pk; Core.eval(Main, Meta.parse("using $p")); end
before = allcis(); lostb = 0
t, c, rc = timed(w); println("after the loads ", r(t), " ms, compile ", r(c), " ms, of it recompile ", r(rc), " ms")
by = Dict{Tuple{Symbol,Bool},Int}(); ex = Dict{Symbol,Vector{Any}}()
for ci in allcis()
    ci in before && continue
    m = ci.def.def; root = m isa Method ? nameof(Base.moduleroot(m.module)) : :toplevel
    k = (root, (ci.flags & FACTS) != 0); by[k] = get(by, k, 0) + 1
    length(get!(ex, root, Any[])) < 4 && push!(ex[root], ci.def.specTypes)
end
println("made after the loads: ", sum(values(by); init = 0), " | ", join(["$(k[1])$(k[2] ? " (facts)" : "") $n" for (k, n) in sort(collect(by); by = last, rev = true)], ", "))
for (root, v) in ex, s in v; println("  ", root, ": ", s); end
