# E-398 (W-152; the review of 2026-11-15, P7 (c)): the `Callable` census.
# Every method whose signature names `Callable`; and, per function, the pairs of methods that a
# `Callable` position tells apart: (a) two `Callable`s with different argument signatures (dispatch by a
# function's signature), (b) a `Callable` against another type a callable value can have.
#     julia --project=<env> census.jl <package>...
for p in ARGS; Core.eval(Main, Meta.parse("using $p")); end
const sysroots = (:Core, :Base)
const CN = Base.unwrap_unionall(Core.Callable).name
root(m::Method) = nameof(Base.moduleroot(m.module))
names_callable(@nospecialize(T), depth = 0) =
    depth > 8 ? false :
    T isa TypeVar ? names_callable(T.ub, depth + 1) :
    T isa UnionAll ? (names_callable(T.var.ub, depth + 1) || names_callable(T.body, depth + 1)) :
    T isa Union ? (names_callable(T.a, depth + 1) || names_callable(T.b, depth + 1)) :
    T isa DataType ? (T.name === CN || any(p -> names_callable(p, depth + 1), T.parameters)) : false
# the `Callable{A, S}` instances a position's type names, at its top (through All, Union, a variable's bound)
function callables(@nospecialize(T), out = Any[], depth = 0)
    depth > 8 && return out
    if T isa TypeVar; callables(T.ub, out, depth + 1)
    elseif T isa UnionAll; callables(T.body, out, depth + 1)
    elseif T isa Union; callables(T.a, out, depth + 1); callables(T.b, out, depth + 1)
    elseif T isa DataType
        if T.name === CN; push!(out, T)
        elseif T.name === Base.unwrap_unionall(Core.All).name; for p in T.parameters; callables(p, out, depth + 1); end
        elseif T.name === Tuple.name && depth > 0; for p in T.parameters; callables(p, out, depth + 1); end
        end
    end
    out
end
params(m::Method) = collect(Base.unwrap_unionall(m.sig).parameters)
# constructors: one key per type name, so that methods at `Type{T}` and `Type{T{...}}` meet
function fkey(@nospecialize(f))
    u = Base.unwrap_unionall(f)
    (u isa DataType && u.name === Base.unwrap_unionall(Type).name) || return f
    t = u.parameters[1]
    t isa TypeVar && (t = t.ub)
    t = Base.unwrap_unionall(t)
    t isa DataType ? t.name : f
end
ms = Method[]; const byf = IdDict{Any,Vector{Method}}()
Base.visit(Core.methodtable) do m
    names_callable(m.sig) && push!(ms, m)
    push!(get!(byf, fkey(params(m)[1]), Method[]), m)
end
by = Dict{Symbol,Int}(); for m in ms; by[root(m)] = get(by, root(m), 0) + 1; end
println("methods whose signature names Callable: ", length(ms), "  ", join(["$k $v" for (k, v) in sort(collect(by); by = last, rev = true)], ", "))
# positions typed by a Callable at the top of an argument
top = [(m, i) for m in ms for i in 2:length(params(m)) if !isempty(callables(params(m)[i]))]
println("  of them with an argument typed by a Callable (not only inside another type): ", length(unique(first.(top))))
for (m, i) in top; println("    ", root(m), " ", m.name, " position ", i - 1, ": ", params(m)[i], "   [", basename(string(m.file)), ":", m.line, "]"); end
replace_at(m, i) = (p = params(m); p[i] = Any; try Base.rewrap_unionall(Tuple{p...}, m.sig) catch; Tuple{p...} end)
arity(m) = (p = params(m); (length(p), !isempty(p) && Base.isvarargtype(p[end])))
seen = Set{Any}(); na = 0; nb = 0; nany = 0
for (m, i) in top
    f = params(m)[1]
    for m2 in get(byf, fkey(f), Method[])
        m2 === m && continue
        arity(m2) == arity(m) || continue
        (m2, m, i) in seen && continue; push!(seen, (m, m2, i))
        # do the other positions leave both methods open to one call?
        s1 = replace_at(m, i); s2 = replace_at(m2, i)
        typeintersect(s1, s2) === Union{} && continue
        T2 = params(m2)[i]; c1 = callables(params(m)[i]); c2 = callables(T2)
        if !isempty(c2)
            a1 = Set(string(c.parameters[1]) for c in c1); a2 = Set(string(c.parameters[1]) for c in c2)
            a1 == a2 && continue
            global na += 1
            println("\n(a) by the function's signature: ", root(m), " ", m.name, " position ", i - 1, "\n      ", params(m)[i], "\n      ", T2, "\n      ", m.file, ":", m.line, "  |  ", m2.file, ":", m2.line)
        elseif T2 === Any
            global nany += 1
            println("\n(any) against an untyped method: ", root(m), " ", m.name, " position ", i - 1, "  ", params(m)[i], "  |  ", m2.file, ":", m2.line)
        else
            global nb += 1
            println("\n(b) against another type: ", root(m), " ", m.name, " position ", i - 1, "\n      ", params(m)[i], "\n      ", T2, "  (", root(m2), ")\n      ", m.file, ":", m.line, "  |  ", m2.file, ":", m2.line)
        end
    end
end
println("\npairs told apart at a Callable position, the other arguments open to one call: (a) two Callables of different signatures ", na, "; (b) a Callable against another type ", nb, "; against an untyped method (Any) ", nany)
