# W-143e (E-541): every fault "a callee named by its MethodInstance alone" (the census's :mi) in a session, by callee,
# with why the edge names an instance:
#   widened  the caller's edges hold a narrower instance of the same method, whose compileable signature is the
#            named one: inference used the narrow instance, the inliner calls the compileable one
#            (`compileable_specialization`), which no inference had made when the caller finished;
#   query    the caller is a query that rests on dispatch (`hasmethod`, `applicable`, …): it names the matched
#            instance (open issue 219);
#   static   an ordinary call with one match, recorded as the matched instance (the edge's form `alone`: the one-edge
#            format of a call whose instance is its match's), where inference's result left no code of it (a recursion
#            cut, a limited result) and the cache held none in the caller's worlds when the caller finished.
# The edge's form: `inliner` (after the method's signature, as `add_inlining_edge!` writes it), `lookup` (a call's
# lookup), `alone`. Per callee: the widening's source (`@nospecialize`, or Julia's own despecialization of a `Type`,
# a `Function`, a `Vararg`), whether the method is `@nospecializeinfer`, and the callee's code now (policy, bit).
#     CENSUS_WORK=table|ode julia --project=envs/<env> diag/mi_why.jl <csv>|-
include(joinpath(@__DIR__, "..", "census_lib.jl"))
const csv = ARGS[1]
S = census_session(csv)
const QUERIES = (:hasmethod, :applicable, :which, :_which, :may_invoke_generator, :hasfield)
inst(e) = e isa Core.CodeInstance ? e.def : e
function why(y::Core.CodeInstance, mi::Core.MethodInstance)
    ym = y.def.def
    ym isa Method && ym.name in QUERIES && return :query, nothing
    m = mi.def; m isa Method || return :static, nothing
    for e in y.edges
        n = inst(e)
        (n isa Core.MethodInstance && n !== mi && n.def === m) || continue
        n.specTypes <: mi.specTypes || continue
        cs = C.get_compileable_sig(m, n.specTypes, n.sparam_vals)
        cs === mi.specTypes && return :widened, n
    end
    return :static, nothing
end
function form(y::Core.CodeInstance, mi::Core.MethodInstance)
    es = y.edges
    for i in 1:length(es)
        inst(es[i]) === mi || continue
        i > 1 && es[i-1] isa Type && mi.def isa Method && es[i-1] === mi.def.sig && return "inliner"
        j = i - 1
        while j >= 1 && !(es[j] isa Int); j -= 1; end
        j >= 1 && j + 1 + abs(es[j]) >= i && return "lookup"
        return "alone"
    end
    return "?"
end
function source(m::Method, narrow, wide)
    m.nospecialize != 0 && return "@nospecialize"
    narrow === nothing && return "-"
    a, b = Base.unwrap_unionall(narrow.specTypes).parameters, Base.unwrap_unionall(wide).parameters
    k = String[]
    for i in 1:min(length(a), length(b))
        a[i] === b[i] && continue
        push!(k, b[i] === Type || (b[i] isa DataType && b[i] <: Type) ? "Type" : b[i] === Function ? "Function" :
                 Base.isvarargtype(b[i]) ? "Vararg" : string(b[i]))
    end
    isempty(k) && length(a) != length(b) && push!(k, "Vararg")
    join(unique(k), ",")
end
codenow(mi) = join(unique([string(isfacts(c) ? "facts" : "plain", bit(c) ? "+bit" : "") for c in micode(mi)]), " ")
rows = Dict{Tuple{Symbol,String},Vector{Any}}()
for (y, k) in S.culprit, f in get(S.fcache, y, Fault[])
    f.kind === :mi || continue
    mi = f.sig::Core.MethodInstance
    w, n = why(y, mi)
    m = mi.def
    key = (w, m isa Method ? string(m.module, ".", m.name) : "?")
    r = get!(rows, key, Any[0, 0, "", "", "", "", ""])
    r[1] += 1; r[2] = max(r[2], get(S.incone, y, 0))
    if r[3] == ""
        r[3] = m isa Method ? source(m, n, mi.specTypes) : "-"
        r[4] = m isa Method && m.nospecializeinfer ? "yes" : "no"
        r[5] = codenow(mi)
        r[6] = string(first(string(y.def.specTypes), 80), " -> ", first(string(mi.specTypes), 80))
        r[7] = form(y, mi)
    end
end
println("why | callee | faults | most cones | widened by | @nospecializeinfer | the edge's form | callee's code now | e.g.")
for (k, r) in sort(collect(rows); by = x -> (-x[2][2], -x[2][1]))
    println(rpad(k[1], 9), rpad(k[2], 40), lpad(r[1], 5), lpad(r[2], 6), "  ", rpad(r[3], 14), rpad(r[4], 4), rpad(r[7], 8), rpad(r[5], 22), r[6])
end
tot = Dict{Symbol,Int}(); cones = Dict{Symbol,Int}()
for (k, r) in rows; tot[k[1]] = get(tot, k[1], 0) + r[1]; end
println("faults by why: ", join(["$k $v" for (k, v) in sort(collect(tot))], ", "))
