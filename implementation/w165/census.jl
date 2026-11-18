# W-165 census (E-503): pairs of methods of one function, of one arity, whose signatures put two different
# instances of one parametric set at the same argument (compiler §4.9). For each: whether Julia reports them
# ambiguous (`Base.isambiguous`) and their signatures' intersection, on the binary that runs this.
# Run after loading the code to census (a package, or nothing for Base and Core):
#     julia --project=<env> census.jl [Package ...]
# One line per pair: `PAIR <ambiguous> | <method 1> | <method 2> | <the set> | <intersection>`.
for p in ARGS
    @eval using $(Symbol(p))
end
isopen(t) = ccall(:jl_is_open_set, Cint, (Any,), t) != 0
isall(t) = t isa DataType && t.name === Base.unwrap_unionall(Core.All).name
# the parametric sets typing one argument itself, with the instance: the argument, an arm of its union, a
# component of its intersection, a variable's bound
function setinsts(t, out = Pair{Core.TypeName,Any}[], d = 0)
    d > 6 && return out
    t isa TypeVar && return setinsts(t.ub, out, d + 1)
    u = Base.unwrap_unionall(t)
    if u isa Union
        setinsts(u.a, out, d + 1); setinsts(u.b, out, d + 1)
    elseif isall(u)
        for c in Base.unwrap_unionall(u.parameters[1]).parameters
            setinsts(c, out, d + 1)
        end
    elseif u isa DataType && !isempty(u.parameters) && isopen(u)
        push!(out, u.name => t)
    end
    return out
end
args(m) = (s = Base.unwrap_unionall(m.sig); s isa DataType ? s.parameters : Core.svec())
function pairs_of(ms)
    out = Any[]
    for i in 1:length(ms), j in i+1:length(ms)
        a, b = args(ms[i]), args(ms[j])
        length(a) == length(b) || continue
        any(x -> x isa Core.TypeofVararg, a) && continue
        for k in 2:length(a)
            sa, sb = setinsts(a[k]), setinsts(b[k])
            hit = nothing
            for (na, ta) in sa, (nb, tb) in sb
                na === nb && !(ta == tb) && (hit = (na, ta, tb))
            end
            hit === nothing && continue
            push!(out, (ms[i], ms[j], hit))
            break
        end
    end
    return out
end
fns = IdDict{Any,Vector{Method}}()
Base.visit(Core.methodtable) do m
    m isa Method || return
    push!(get!(Vector{Method}, fns, Base.unwrap_unionall(m.sig).parameters[1]), m)
end
n = 0
for (f, ms) in fns
    length(ms) < 2 && continue
    any(m -> !isempty(setinsts(m.sig)) || occursin("Callable", string(m.sig)), ms) || continue
    for (m1, m2, (name, ta, tb)) in pairs_of(ms)
        global n += 1
        amb = try Base.isambiguous(m1, m2) catch e; "error $(typeof(e))" end
        ti = try typeintersect(m1.sig, m2.sig) catch e; "error $(typeof(e))" end
        println("PAIR ", amb, " | ", m1, " | ", m2, " | ", name.name, ": ", ta, " vs ", tb, " | ", ti)
    end
end
println("census: $n pairs, ", length(fns), " functions; julia ", Base.GIT_VERSION_INFO.commit_short)
