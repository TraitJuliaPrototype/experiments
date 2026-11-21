# C-157, diagnosis: the machine code that runs for `passes` (the CodeInstance's specptr), read after the call:
# the calls it makes (a typeassert's type error, the `if`'s).
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
for mi in Base.specializations(only(methods(passes)))
    ci = mi.cache
    while true
        p = getfield(ci, :specptr)
        println("ci ", ci.min_world, " owner ", ci.owner, " specptr ", p)
        if p != C_NULL
            s = ccall(:jl_dump_fptr_asm, Any, (UInt64, Cchar, Cstring, Cstring, Cchar), UInt64(p), 0, "att", "none", 0)
            for l in split(s, '\n')
                println("   ", strip(l))
            end
        end
        isdefined(ci, :next) || break
        ci = ci.next
    end
end
