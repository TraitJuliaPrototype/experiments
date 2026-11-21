# C-157, diagnosis: what is compiled for `passes` and `t(x)`, and which instance runs.
using TraitWorld
module Sig
using TraitWorld
@trait_module
export passes, passes_all
function passes(tests::Vector{Callable{Tuple{Float64}, Bool}}, x::Float64)
    n = 0
    for t in tests
        t(x) && (n += 1)
    end
    return n
end
passes_all(tests::Vector{Callable{Tuple{Float64}, Bool}}, x) = all(t -> t(x), tests)
end
using .Sig
const T = Vector{Callable{Tuple{Float64}, Bool}}
function cis(f, sig)
    m = only(methods(f))
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        println("  mi ", mi.specTypes)
        isdefined(mi, :cache) || continue
        ci = mi.cache
        while ci !== nothing
            fl = isdefined(Core.CodeInstance, :flags) ? getfield(ci, :flags) : nothing
            println("    ci worlds ", ci.min_world, ":", ci.max_world == typemax(UInt) ? "∞" : ci.max_world,
                    " rettype ", ci.rettype, " owner ", ci.owner === nothing ? "nothing" : ci.owner,
                    " invoke ", ci.invoke != C_NULL, " src ", isdefined(ci, :inferred) ? typeof(ci.inferred) : "-")
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
println("== before any call")
cis(passes, nothing)
println("== code_typed passes")
display(Base.code_typed(passes, (T, Float64)))
r = try passes(Callable{Tuple{Float64}, Bool}[x -> 1], 2.0) catch e; e end
println("== result: ", r isa Exception ? sprint(showerror, r) : repr(r))
println("== after the call")
cis(passes, nothing)
r = try passes_all(Callable{Tuple{Float64}, Bool}[x -> 1], 2.0) catch e; e end
println("== passes_all result: ", r isa Exception ? sprint(showerror, r) : repr(r))
display(Base.code_typed(passes_all, (T, Float64)))
