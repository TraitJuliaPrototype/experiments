# W-19, third part: the duplicate check of `store_backedges` over the forward edges of every CodeInstance after
# `using CSV, DataFrames`, timed in the session's own world for three forms: the iterator walked twice with the
# call-signature pair as a new type (It0), the same with that pair typed `Any` for inference (It2, the fix), and
# the pairs collected into a `Vector{Any}` first (the form of the first `up/19`). No backedge is stored.
#     julia --project=envs/up g-dupcheck.jl
const C = Base.Compiler
using .C: CodeInstance, MethodInstance, MethodTable, get_ci_mi, CallSigBackedge
struct It2; forward_edges::Core.SimpleVector; end
function Base.iterate(it::It2, i::Int = 1)
    edges = it.forward_edges
    i > length(edges) && return nothing
    while i ≤ length(edges)
        item = edges[i]
        if item isa Int
            if item == 1 && i + 2 <= length(edges)
                callee = edges[i+2]
                if callee isa CodeInstance || callee isa MethodInstance
                    mi = (callee isa CodeInstance ? get_ci_mi(callee) : callee)::MethodInstance
                    sig = edges[i+1]
                    if sig isa Type && mi.specTypes !== sig
                        return ((Core.compilerbarrier(:type, CallSigBackedge(sig)), mi), i + 3)
                    end
                end
            end
            i += 2
            continue
        elseif isa(item, Method)
            i += 1
            continue
        elseif isa(item, Core.Binding)
            return ((nothing, item), i + 1)
        end
        if isa(item, CodeInstance)
            item = get_ci_mi(item)
            return ((nothing, item), i + 1)
        elseif isa(item, MethodInstance)
            return ((nothing, item), i + 1)
        else
            invokesig = item
            callee = edges[i+1]
            isa(callee, Method) && (i += 2; continue)
            if isa(callee, MethodTable)
                return ((invokesig, callee), i + 2)
            else
                callee = isa(callee, CodeInstance) ? get_ci_mi(callee) : callee::MethodInstance
                return ((invokesig, callee), i + 2)
            end
        end
    end
    return nothing
end
struct It0; forward_edges::Core.SimpleVector; end
function Base.iterate(it::It0, i::Int = 1)
    edges = it.forward_edges
    i > length(edges) && return nothing
    while i ≤ length(edges)
        item = edges[i]
        if item isa Int
            if item == 1 && i + 2 <= length(edges)
                callee = edges[i+2]
                if callee isa CodeInstance || callee isa MethodInstance
                    mi = (callee isa CodeInstance ? get_ci_mi(callee) : callee)::MethodInstance
                    sig = edges[i+1]
                    if sig isa Type && mi.specTypes !== sig
                        return ((CallSigBackedge(sig), mi), i + 3)
                    end
                end
            end
            i += 2
            continue
        elseif isa(item, Method)
            i += 1
            continue
        elseif isa(item, Core.Binding)
            return ((nothing, item), i + 1)
        end
        if isa(item, CodeInstance)
            item = get_ci_mi(item)
            return ((nothing, item), i + 1)
        elseif isa(item, MethodInstance)
            return ((nothing, item), i + 1)
        else
            invokesig = item
            callee = edges[i+1]
            isa(callee, Method) && (i += 2; continue)
            if isa(callee, MethodTable)
                return ((invokesig, callee), i + 2)
            else
                callee = isa(callee, CodeInstance) ? get_ci_mi(callee) : callee::MethodInstance
                return ((invokesig, callee), i + 2)
            end
        end
    end
    return nothing
end

function walk2(::Type{It}, edges) where It
    n = 0
    for (i, (invokesig, item)) in enumerate(It(edges))
        dup = false
        for (i′, (invokesig′, item′)) in enumerate(It(edges))
            i == i′ && break
            if item′ === item && invokesig′ == invokesig
                dup = true; break
            end
        end
        dup || (n += 1)
    end
    return n
end
function collected(edges)
    bes = Any[]
    for be in It0(edges)
        push!(bes, be)
    end
    n = 0
    for i in 1:length(bes)
        invokesig, item = bes[i]::Tuple{Any,Any}
        dup = false
        for i′ in 1:(i - 1)
            invokesig′, item′ = bes[i′]::Tuple{Any,Any}
            if item′ === item && invokesig′ === invokesig
                dup = true; break
            end
        end
        dup || (n += 1)
    end
    return n
end
@eval using CSV, DataFrames
lists = Core.SimpleVector[]
Base.visit(Core.methodtable) do m
    for mi in Base.specializations(m)
        mi isa MethodInstance || continue
        isdefined(mi, :cache) || continue
        ci = mi.cache
        while true
            isempty(ci.edges) || push!(lists, ci.edges)
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
end
println(Base.return_types(iterate, (It0, Int)), "\n", Base.return_types(iterate, (It2, Int)))
runall(f, lists) = (s = 0; for e in lists; s += f(e); end; s)
for k in 1:3
    for (name, f) in (("It0 walked twice", e -> walk2(It0, e)), ("It2 walked twice", e -> walk2(It2, e)), ("collected", collected))
        runall(f, lists[1:10])
        GC.gc()
        t = @elapsed s = runall(f, lists)
        println(rpad(name, 18), round(1000t; digits = 1), " ms over ", length(lists), " edge lists (", s, " backedges)")
    end
end
