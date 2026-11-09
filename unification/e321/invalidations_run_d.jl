# E-321: invalidations during setting D's script (insertions and memberships), those reaching ForwardDiff's code.
#   cd experiments/ttfx && WL_D=trait ... julia --project=../unification/e289/env_d_unified invalidations_run_d.jl <pngdir>
ins = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
const N0 = Ref(0)
try
    include(joinpath(pwd(), "workload_d.jl"))
finally
    ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
end
println("insertion log: ", length(ins), " entries")
cur = Any[]; shown = 0
for x in ins
    if x isa Core.MethodInstance || x isa Core.CodeInstance
        push!(cur, x)
    elseif x isa Integer || x isa AbstractString
        x isa AbstractString && push!(cur, x)
    else
        if any(y -> occursin("ForwardDiff", string(y)), cur)
            global shown += 1
            shown <= 10 && println("CAUSE ", first(sprint(show, x), 300), "\n   ", length(cur), " entries: ", join((first(string(y), 150) for y in cur[1:min(end, 8)]), "\n   "))
        end
        empty!(cur)
    end
end
println("causes reaching ForwardDiff: ", shown)
