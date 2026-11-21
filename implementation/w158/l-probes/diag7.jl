# C-157, diagnosis: the LLVM the JIT's source gives, unoptimized and optimized: is the result's typeassert there?
include(joinpath(@__DIR__, "trace_jit.jl"))
push!(TRACE_NAMES, :passes); TRACE_PRINT[] = false
using InteractiveUtils
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
for (mi, src) in TRACE_SRCS, opt in (false, true)
    s = InteractiveUtils._dump_function_llvm(mi, src, false, true, false, opt, :none, Base.CodegenParams())
    println("== optimize=$opt: type_error ", count("type_error", s), ", typeassert ", count("typeassert", s),
            ", non-boolean/bool check ", count("jl_bool_type", s) + count("if\"", s))
    opt || for l in split(s, '\n'); occursin(r"apply_generic|type_error|typeassert|jl_true|jl_false|icmp eq ptr", l) && println("   ", strip(l)); end
end
