# W-145, part 2: one session of a cache workload, with marks and each compile attributed to the
# package whose method it is.
#     julia --project=<dir>/env session.jl <dir>
# Marks: the loads (`loads.jl`: the packages), the session's own definitions (`body.jl`: a membership
# declared in the session, `main`), the first run of `main`, a second run. Every CodeInstance made
# after the loads is listed by the root module of its method, with its own inference time
# (`time_infer_self`) and its code generation time (`time_compile`): inference is given to the method
# inferred, wherever its root is; code generation to the instance compiled, with what is inlined in it.
dir = abspath(ARGS[1])
t0 = time_ns()
include(joinpath(dir, "loads.jl"))
t1 = time_ns()
module Harness           # the harness's own code, compiled before the session's code is counted
function allcis()
    out = Base.IdSet{Core.CodeInstance}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                push!(out, ci)
                isdefined(ci, :next) || break
                ci = ci.next
            end
        end
        return true
    end
    return out
end
secs(x::UInt16) = Float64(reinterpret(Float16, x))
rootname(ci) = (d = ci.def; d isa Core.MethodInstance || (d = d.def); m = d.def; string(Base.moduleroot(m isa Method ? m.module : m)))
function class(ci)
    r = rootname(ci)
    d = ci.def; d isa Core.MethodInstance || (d = d.def)
    names_ring = occursin("Ring", string(d.specTypes))
    r == "SeriesA" && return names_ring ? "A's method at B's type" : "A's method, other"
    r in ("RingB", "GlueC", "RingBSeriesAExt") && return r == "RingB" ? "B's method" : "the glue's method"
    r == "Main" && return "the session's own"
    r == "TraitWorld" && return "TraitWorld's"
    return names_ring ? "Julia's method at B's type" : "Julia's own"
end
function attribute(before)
    acc = Dict{String, Vector{Float64}}()
    for ci in allcis()
        (ci in before || ci.owner !== nothing) && continue
        a = get!(acc, class(ci), [0.0, 0.0, 0.0])
        a[1] += 1; a[2] += secs(ci.time_infer_self); a[3] += secs(ci.time_compile)
    end
    return acc
end
function timed(@nospecialize(f))
    redirect_stdout(devnull) do
        a = time_ns(); Base.invokelatest(f, String[]); time_ns() - a
    end
end
ms(x) = round(x / 1e6; digits = 1)
function report(io, t, c, acc)
    println(io, "MARKS load ", ms(t[1]), " ms | body ", ms(t[2]), " ms | first run ", ms(t[3]), " ms, of it compiling ",
            ms(c), " ms | second run ", ms(t[4]), " ms")
    for k in sort!(collect(keys(acc)))
        a = acc[k]
        println(io, "CLASS ", k, " | ", Int(a[1]), " | ", round(1e3 * a[2]; digits = 1), " | ", round(1e3 * a[3]; digits = 1))
    end
end
warm(args) = 0
end
# the harness runs once on nothing, so that its own code is compiled before the count
let b = Harness.allcis()
    Harness.timed(Harness.warm); Harness.report(devnull, (1, 1, 1, 1), 1, Harness.attribute(b))
end
before = Harness.allcis()
t2 = time_ns()
include(joinpath(dir, "body.jl"))
t3 = time_ns()
c0 = Base.cumulative_compile_time_ns(); Base.cumulative_compile_timing(true)
out1 = Harness.timed(main)
c1 = Base.cumulative_compile_time_ns(); Base.cumulative_compile_timing(false)
out2 = Harness.timed(main)
Harness.report(stdout, (t1 - t0, t3 - t2, out1, out2), c1[1] - c0[1], Harness.attribute(before))
