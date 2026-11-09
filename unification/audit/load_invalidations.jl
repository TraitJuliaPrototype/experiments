# The load report: what loading packages invalidates or rejects, grouped by cause, so that a common
# pattern stands out (a kind of method, a set, a membership). Run in a session's environment:
#     julia-unified/julia --startup-file=no --project=<env> experiments/unification/audit/load_invalidations.jl CSV,DataFrames,TraitMakie [n]
# It loads the packages with Julia's invalidation log on and prints:
#   - the log's tags with their counts;
#   - the causes that invalidated compiled code at their insertion (a method, its module, the instances
#     it invalidated, the first few of them);
#   - the package images' code rejected at its validation, grouped by the edge that failed.
# A report: it asserts nothing.
pkgs = Symbol.(split(ARGS[1], ","))
nshow = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 25

t0 = time()
invs = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
for p in pkgs
    Core.eval(Main, :(using $p))
end
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
println("# loaded ", join(pkgs, ", "), " in ", round(time() - t0; digits = 2), " s; log entries: ", length(invs))

mi_of(x) = x isa Core.CodeInstance ? x.def isa Core.MethodInstance ? x.def : x.def.def : x
function sh(x)
    x = mi_of(x)
    x isa Core.MethodInstance ? string(x.specTypes) * (x.def isa Method ? "  [" * string(x.def.module) * "]" : "") :
    x isa Method ? string(x.module) * ": " * string(x.sig) : first(repr(x), 200)
end
modof(x) = (x = mi_of(x); x isa Core.MethodInstance && x.def isa Method ? x.def.module :
            x isa Method ? x.module : nothing)
rootmod(m) = m === nothing ? nothing : (p = parentmodule(m); p === m || p === Main ? m : rootmod(p))

tags = Dict{String,Int}()
for x in invs
    x isa String && (tags[x] = get(tags, x, 0) + 1)
end
println("# tags: ", join(["$k $v" for (k, v) in sort(collect(tags); by = p -> -p[2])], "; "))

# insertions: [instance, depth]... method "jl_method_table_insert"; invalidate_mt_cache: instance tag
causes = Dict{Any,Vector{Any}}()
pending = Any[]
rejected = Dict{Any,Vector{Any}}()
i = 1
while i <= length(invs)
    x = invs[i]
    if x isa String
        if x == "jl_method_table_insert" || x == "jl_method_table_disable"
            cause = pending_cause
            append!(get!(Vector{Any}, causes, cause), pending)
            empty!(pending)
        elseif x == "verify_methods" || startswith(x, "insert_backedges")
            # the rejected instance before the tag; the cause after it
            c = i + 1 <= length(invs) ? invs[i+1] : nothing
            inst = i - 1 >= 1 ? invs[i-1] : nothing
            push!(get!(Vector{Any}, rejected, (x, c isa String ? c : c isa Integer ? "edge #$c" : sh(c))), inst)
            filter!(y -> y !== inst, pending)
        elseif x == "invalidate_mt_cache"
            filter!(y -> y !== invs[i-1], pending)
        end
    elseif x isa Method
        global pending_cause = x
    elseif x isa Core.MethodInstance || x isa Core.CodeInstance
        push!(pending, x)
    end
    global i += 1
end

ninv = sum(length, values(causes); init = 0)
println("# invalidated at an insertion: $ninv instances by $(length(causes)) methods")
bymod = Dict{Any,Int}()
for (c, v) in causes
    m = rootmod(modof(c))
    bymod[m] = get(bymod, m, 0) + length(v)
end
println("# by the inserting package: ", join(["$k $v" for (k, v) in sort(collect(bymod); by = p -> -p[2])], "; "))
# by the inserted method's signature shape: the function and which argument types are sets
shape(c) = c isa Method ? (s = Base.unwrap_unionall(c.sig); s isa DataType ?
    string(s.parameters[1]) * "(" * join([ccall(:jl_is_open_set, Cint, (Any,), Base.unwrap_unionall(p) isa DataType ? Base.unwrap_unionall(p) : Any) == 1 ? "<set " * string(p) * ">" : "_" for p in s.parameters[2:end]], ", ") * ")" : "?") : "?"
byshape = Dict{String,Tuple{Int,Int}}()
for (c, v) in causes
    k = shape(c)
    a, b = get(byshape, k, (0, 0))
    byshape[k] = (a + 1, b + length(v))
end
println("# by the inserted method's shape (methods, instances):")
for (k, (a, b)) in first(sort(collect(byshape); by = p -> -p[2][2]), nshow)
    println("    ", rpad(k, 70), lpad(a, 5), lpad(b, 7))
end
println("# the methods that invalidated most:")
for (c, v) in first(sort(collect(causes); by = p -> -length(p[2])), nshow)
    println(lpad(length(v), 6), "  ", first(sh(c), 180))
    for y in first(v, 3)
        println("            ", first(sh(y), 170))
    end
end
# the roots under the first causes: the entries at depth 0 (an instance, then its depth), what the
# insertion hit directly, grouped by the root's function and argument types (sets marked)
roots = Dict{Any,Vector{Any}}()
let cur = Any[]
    for k in 1:length(invs)
        x = invs[k]
        if (x isa Core.MethodInstance || x isa Core.CodeInstance) && k < length(invs) && invs[k+1] === 0
            push!(cur, x)
        elseif x isa Type
            push!(cur, x)             # a missing backedge's type (the arm pruned)
        elseif x isa Method && k < length(invs) && invs[k+1] == "jl_method_table_insert"
            append!(get!(Vector{Any}, roots, x), cur)
            empty!(cur)
        end
    end
end
println("# the roots (depth 0) under the methods that invalidated most:")
for (c, v) in first(sort(collect(causes); by = p -> -length(p[2])), 4)
    rs = get(roots, c, Any[])
    println("  ", first(sh(c), 120), ": ", length(rs), " roots")
    g = Dict{String,Int}()
    for r in rs
        s = r isa Type ? "pruned " * string(r) : sh(r)
        g[s] = get(g, s, 0) + 1
    end
    for (s, n) in first(sort(collect(g); by = p -> -p[2]), 12)
        println(lpad(n, 8), "  ", first(s, 170))
    end
end
# invalidation through a split's branch: the callee is a candidate's instance of an operation (the
# receiver's type a candidate of a set, the method one of the function's declared methods), the caller an
# instance whose argument there is typed by the set. The caller uses only the declared result, yet its
# edge to the candidate's instance carries the invalidation of everything under it. The log is depth-first:
# an entry at depth d+1 is a caller of the nearest entry before it at depth d.
issetT(@nospecialize T) = (u = Base.unwrap_unionall(T); u isa DataType && ccall(:jl_is_open_set, Cint, (Any,), u) == 1)
function split_edge(callee, caller)
    a, b = mi_of(callee), mi_of(caller)
    (a isa Core.MethodInstance && b isa Core.MethodInstance && a.def isa Method && b.def isa Method) || return nothing
    sa, sb = Base.unwrap_unionall(a.specTypes), Base.unwrap_unionall(b.specTypes)
    (sa isa DataType && sb isa DataType && length(sa.parameters) >= 2) || return nothing
    ops = ccall(:jl_declared_methods_of, Any, (Any,), sa.parameters[1])::Vector{Any}
    isempty(ops) && return nothing
    for om in ops
        os = Base.unwrap_unionall(om.sig)
        for k in 2:min(length(os.parameters), length(sa.parameters))
            issetT(os.parameters[k]) || continue
            sa.parameters[k] <: os.parameters[k] || continue
            # the caller holds a value of the set: some argument of it typed by the set itself
            any(issetT, sb.parameters[2:end]) && return (sa.parameters[1], sa.parameters[k])
        end
    end
    return nothing
end
let entries = Tuple{Any,Int}[]
    for k in 1:length(invs)-1
        x = invs[k]
        (x isa Core.MethodInstance || x isa Core.CodeInstance) && invs[k+1] isa Integer && push!(entries, (x, invs[k+1]))
    end
    through = Dict{Any,Tuple{Int,Int}}()   # (function, candidate) => (edges, instances under them)
    last_at = Dict{Int,Any}()
    q = 1
    while q <= length(entries)
        x, d = entries[q]
        last_at[d] = x
        if d > 0 && haskey(last_at, d - 1)
            e = split_edge(last_at[d-1], x)
            if e !== nothing
                n = 1                       # the caller and everything after it at a greater depth
                while q + n <= length(entries) && entries[q+n][2] > d
                    n += 1
                end
                a, b = get(through, e, (0, 0))
                through[e] = (a + 1, b + n)
            end
        end
        q += 1
    end
    tot = sum(p -> p[2], values(through); init = 0)
    println("# through a split's branch: $tot instances under $(sum(p -> p[1], values(through); init = 0)) edges (operation, candidate: edges, instances):")
    for (e, (a, b)) in first(sort(collect(through); by = p -> -p[2][2]), nshow)
        println(lpad(b, 8), "  ", e[1], " at ", e[2], " (", a, " edges)")
    end
end
nrej = sum(length, values(rejected); init = 0)
println("# rejected at an image's validation: $nrej instances, $(length(rejected)) causes")
for ((t, c), v) in first(sort(collect(rejected); by = p -> -length(p[2])), nshow)
    println(lpad(length(v), 6), "  ", t, "  ", first(string(c), 160))
    for y in first(v, 2)
        println("            ", first(sh(y), 170))
    end
end
