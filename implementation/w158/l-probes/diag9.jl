# C-157, diagnosis of the `all` form: the closure's code, `_all`'s code, and the source the JIT is given for `_all`.
include(joinpath(@__DIR__, "trace_jit.jl"))
append!(TRACE_NAMES, [:_all, :passes_all]); TRACE_PRINT[] = false
const Callable = Core.Callable
passes_all(tests::Vector{Callable{Tuple{Float64}, Bool}}, x) = all(t -> t(x), tests)
v = Callable{Tuple{Float64}, Bool}[x -> 1]
r = try passes_all(v, 2.0) catch e; e end
println("result: ", r isa Exception ? sprint(showerror, r) : repr(r))
for (mi, src) in TRACE_SRCS
    println("== JIT source of ", mi)
    display(src)
end
cl = typeof(t -> t(2.0))
