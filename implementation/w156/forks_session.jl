# W-156, second part: the forks' session (`forks/scripts/session_check.jl`, the 26 steps of the REPL workload as
# digests), timed in one process: the load and the session together, and of it compiling
# (`Base.cumulative_compile_time_ns`). The digests go to the file DIGESTS. With INSTANCES=<file>, after the session,
# every method instance of the forks' packages (Tables, CSV, DataFrames and their extensions) that holds code
# is written there, one line each: `module<TAB>method<TAB>file:line<TAB>specTypes`.
#     DATA=forks/data DIGESTS=<file> [INSTANCES=<file>] julia --project=env_session forks_session.jl
t0 = time_ns()
const SCRIPT = joinpath(@__DIR__, "..", "..", "..", "forks", "scripts", "session_check.jl")
Base.cumulative_compile_timing(true)
c0 = Base.cumulative_compile_time_ns()
open(ENV["DIGESTS"], "w") do io
    redirect_stdout(io) do
        include(SCRIPT)
    end
end
c1 = Base.cumulative_compile_time_ns()
Base.cumulative_compile_timing(false)
t1 = time_ns()
println("session ", round((t1 - t0) / 1e6; digits = 1), " ms, of it compiling ", round((c1[1] - c0[1]) / 1e6; digits = 1),
        " ms (recompiling ", round((c1[2] - c0[2]) / 1e6; digits = 1), " ms)")

const ROOTS = ("Tables", "CSV", "DataFrames")
fork_module(m::Module) = (r = string(nameof(Base.moduleroot(m))); any(p -> startswith(r, p), ROOTS))
if !isempty(get(ENV, "INSTANCES", ""))
    n = Ref(0)
    open(ENV["INSTANCES"], "w") do io
        Base.visit(Core.methodtable) do m
            m isa Method && fork_module(m.module) || return
            for mi in Base.specializations(m)
                mi === nothing && continue
                isdefined(mi, :cache) || continue
                println(io, nameof(Base.moduleroot(m.module)), '\t', m.name, '\t', basename(string(m.file)), ':', m.line,
                        '\t', replace(string(mi.specTypes), '\n' => ' ', '\t' => ' '))
                n[] += 1
            end
        end
    end
    println("instances with code in the forks' packages: $(n[])")
end
