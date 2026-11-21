# W-158, third part (item 5): the build's rounds as 61277571fa ran them, laid over the session: a caller is found by
# an invoke statement that names a stale code instance, so a caller that invokes the instance's code inferred with
# constants (a code instance of its own) is kept. Included by `stale_invoke.jl` with OLD=1.
Core.eval(Base.Compiler, quote
function closed_invalidate_callers!(codeinfos::Vector{Any}, stale::IdSet{Any}, world::UInt, @nospecialize(owner = nothing))
    changed = true
    while changed
        changed = false
        callee = nothing
        for item in codeinfos
            if item isa CodeInstance
                callee = item
                continue
            end
            (item isa CodeInfo && callee isa CodeInstance && !(callee in stale)) || continue
            for stmt in item.code
                isexpr(stmt, :(=)) && (stmt = stmt.args[2])
                (isexpr(stmt, :invoke) && stmt.args[1] in stale) || continue
                push!(stale, callee)
                if callee.owner === owner && callee.max_world == typemax(UInt)
                    ccall(:jl_invalidate_code_instance, Cvoid, (Any, UInt), callee, world - 1)
                end
                changed = true
                break
            end
        end
    end
    return nothing
end
end)
