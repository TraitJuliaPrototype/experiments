# The set-to-methods index against the signatures (compiler §5.1, §5.5): a membership's walk replays the
# methods the index lists under the set. A method whose signature names a set in a shape the index does
# not walk is never replayed, and a call cached before a membership keeps its answer. This report walks
# every method's signature by itself (parameters, unions, `Vararg`, a `where`'s body, a variable's bounds)
# and lists each (method, set) the index does not hold. It asserts nothing.
#
#   julia --startup-file=no --project=<env> set_index.jl [Pkg,…] [n]
pkgs = isempty(ARGS) ? String[] : filter(!isempty, split(ARGS[1], ","))
nshow = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 20
for p in pkgs
    @eval using $(Symbol(p))
end
isset(tn::Core.TypeName) = ccall(:jl_is_open_set, Cint, (Any,), tn.wrapper) != 0
function names!(out::Set{Core.TypeName}, @nospecialize(t), seen = Base.IdSet{Any}(), depth = 0)
    (depth > 12 || t in seen) && return out
    push!(seen, t)
    if t isa TypeVar
        names!(out, t.lb, seen, depth + 1); names!(out, t.ub, seen, depth + 1)
    elseif t isa UnionAll
        names!(out, t.var, seen, depth + 1); names!(out, t.body, seen, depth + 1)
    elseif t isa Union
        names!(out, t.a, seen, depth + 1); names!(out, t.b, seen, depth + 1)
    elseif t isa Core.TypeofVararg
        isdefined(t, :T) && names!(out, t.T, seen, depth + 1)
    elseif t isa DataType
        isset(t.name) && push!(out, t.name)
        for p in t.parameters
            names!(out, p, seen, depth + 1)
        end
    end
    return out
end
indexed = Dict{Core.TypeName, Base.IdSet{Any}}()
listed(tn) = get!(() -> Base.IdSet{Any}(ccall(:jl_open_set_methods_of, Any, (Any,), tn.wrapper)), indexed, tn)
nmeth = 0; nset = 0; pairs = 0
missing_pairs = Tuple{Method, Core.TypeName}[]
Base.visit(Core.methodtable) do m
    global nmeth += 1
    ccall(:jl_has_open_set, Cint, (Any,), m.sig) == 0 && return
    global nset += 1
    for tn in names!(Set{Core.TypeName}(), m.sig)
        global pairs += 1
        m in listed(tn) || push!(missing_pairs, (m, tn))
    end
end
println("methods ", nmeth, "; with a set in the signature ", nset, "; (method, set) pairs ", pairs,
        "; not in the index ", length(missing_pairs))
for (m, tn) in first(missing_pairs, nshow)
    println("  ", tn.name, "  ", m.sig)
end
