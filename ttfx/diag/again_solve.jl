# W-22 (E-196): what the repeated solve compiles in setting A. From the first solve's mark: the runtime's
# invalidation log; in the repeated solve: the CodeInstances inferred, by owner and method.
const NEW = Any[]
const LOG = Ref{Any}(nothing)
function _on_mark(step)
    if step == "solve1"
        LOG[] = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
    elseif step == "model2"
        ccall(:jl_set_newly_inferred, Cvoid, (Any,), NEW)
    elseif step == "again_solve"
        ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
        log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
        cnt = Dict{Any,Int}()
        for ci in NEW; ci isa Core.CodeInstance || continue; cnt[ci.owner] = get(cnt, ci.owner, 0) + 1; end
        println(stderr, "X inferred in the repeated solve, by owner: ", cnt)
        for ci in NEW[1:min(end, 40)]
            ci isa Core.CodeInstance && println(stderr, "X   ", ci.owner, "  ", first(string(Core.Compiler.get_ci_mi(ci)), 160))
        end
        println(stderr, "X invalidation log entries from solve1 to the repeated solve: ", log isa Vector ? length(log) : log)
        if log isa Vector
            for (k, x) in enumerate(log)
                x isa String && println(stderr, "X   ", x, " <= ", first(string(log[k-1]), 160))
            end
        end
    end
end
include(joinpath(@__DIR__, "..", "workload.jl"))
