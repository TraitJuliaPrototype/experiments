# E-358, the follow-up: what a session compiles at a member's first use, and the core's work alone, repeated.
#     JULIA_LOAD_PATH=... julia probe.jl trait|plain
const kind = ARGS[1]
const corename = kind == "trait" ? :CompCore : :PCore
const prefix = kind == "trait" ? "CompM" : "PM"
const C = Base.require(Main, corename)
function all_ci()
    s = IdSet{Any}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                ci.owner === nothing && push!(s, ci)
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    s
end
const v = Base.invokelatest(() -> C.Shape[])
all_ci(); Base.cumulative_compile_timing(true)
for i in 1:6
    m = Base.require(Main, Symbol(prefix, lpad(i, 2, '0')))
    Base.invokelatest(push!, v, Base.invokelatest(m.make))
    before = all_ci(); c0 = Base.cumulative_compile_time_ns()[1]
    t = @elapsed Base.invokelatest(C.work, v)
    c = (Base.cumulative_compile_time_ns()[1] - c0) / 1e6
    new = [ci for ci in all_ci() if !(ci in before)]
    println("member ", i, ": the core's work ", round(1000t; digits = 2), " ms (compile ", round(c; digits = 2), " ms); new instances ", length(new))
    i in (2, 6) && for ci in new[1:min(end, 12)]; println("    ", (ci.flags & 0x20) != 0 ? "facts " : "plain ", ci.def.specTypes); end
end
for i in 7:20
    m = Base.require(Main, Symbol(prefix, lpad(i, 2, '0'))); Base.invokelatest(push!, v, Base.invokelatest(m.make))
end
Base.invokelatest(C.work, v)
f() = (b = typemax(Float64); for _ in 1:2000; t = @elapsed C.work(v); b = min(b, t); end; b)
println("the core's work on 20 members, the least of 2,000: ", round(1e6 * Base.invokelatest(f); digits = 2), " µs")
