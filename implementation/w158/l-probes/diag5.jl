# C-157, diagnosis: which code runs for `passes` after the call: compiled or interpreted, and its flags.
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
mi = only(Base.specializations(only(methods(passes))))
ci = mi.cache
interp_ptr = try cglobal(:jl_fptr_interpret_call) catch; C_NULL end
println("invoke ", getfield(ci, :invoke), " interpret? ", getfield(ci, :invoke) == interp_ptr, " specptr ", getfield(ci, :specptr), " flags ", ci.flags,
        " rettype ", ci.rettype, " ipo ", ci.ipo_purity_bits)
for name in (:jl_fptr_args, :jl_fptr_sparam, :jl_fptr_const_return, :jl_fptr_wait_for_compiled)
    p = try cglobal(name) catch; C_NULL end
    println("  ", name, " ", p, " ", getfield(ci, :invoke) == p)
end
