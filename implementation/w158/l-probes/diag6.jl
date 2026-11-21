# C-157, diagnosis: the source the JIT is given for `passes`.
include(joinpath(@__DIR__, "trace_jit.jl"))
push!(TRACE_NAMES, :passes)
const Callable = Core.Callable
function passes(tests::Vector{Callable{Tuple{Float64}, Bool}}, x::Float64)
    n = 0
    for t in tests
        t(x) && (n += 1)
    end
    return n
end
v = Callable{Tuple{Float64}, Bool}[x -> 1]
r = try passes(v, 2.0) catch e; e end
println("result: ", r isa Exception ? sprint(showerror, r) : repr(r))
