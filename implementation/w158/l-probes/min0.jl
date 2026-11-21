# C-157 without the library: Core.Callable only, at Main. MODE=typed runs code_typed first; MODE=llvm code_llvm first.
const Callable = Core.Callable
function passes(tests::Vector{Callable{Tuple{Float64}, Bool}}, x::Float64)
    n = 0
    for t in tests
        t(x) && (n += 1)
    end
    return n
end
mode = get(ENV, "MODE", "")
v = Callable{Tuple{Float64}, Bool}[x -> 1]
mode == "typed" && Base.code_typed(passes, (typeof(v), Float64))
mode == "llvm" && (using InteractiveUtils; code_llvm(devnull, passes, (typeof(v), Float64)))
r = try passes(v, 2.0) catch e; e end
println("MODE=", repr(mode), " result: ", r isa Exception ? sprint(showerror, r) : repr(r))
