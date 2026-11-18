# E-233/E-234: CodeInstances a session creates after its load, included into a running session (the REPL's or a
# script's). E-175's walk (`experiments/ttfx/cache/record_cis.jl`), as functions:
#     _snap!()            at the load mark: the CodeInstances that came with the load
#     _split!()           after a late `using` (the forks' `using InlineStrings`): the modules it brought
#     _count(io)          the new CodeInstances by owner and by the root module of their method (E-233's breakdown)
#     _record(stmts)      E-234: the types to replay, serialized one by one (`<stmts>-1.jls`, `-2.jls`: before and
#                         after the split), and TraitWorld's first-call checks of the session
const _MT = isdefined(Core, :GlobalMethods) ? Core.GlobalMethods : Core.methodtable
function _cis()
    s = Base.IdSet{Any}()
    Base.visit(_MT) do m
        for mi in Base.specializations(m)
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci isa Core.CodeInstance
                push!(s, ci)
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    s
end
_mentions(@nospecialize(T), pred) =
    T isa Union ? (_mentions(T.a, pred) || _mentions(T.b, pred)) :
    T isa UnionAll ? (_mentions(T.var.lb, pred) || _mentions(T.var.ub, pred) || _mentions(T.body, pred)) :
    T isa TypeVar ? (_mentions(T.lb, pred) || _mentions(T.ub, pred)) :
    T isa Core.TypeofVararg ? (isdefined(T, :T) && _mentions(T.T, pred)) :
    T isa DataType ? (pred(parentmodule(T)) || any(p -> _mentions(p, pred), T.parameters)) :
    T isa Tuple ? any(p -> _mentions(p, pred), T) : false
_names_main(@nospecialize(T)) = _mentions(T, m -> m === Main)
const _BEFORE = Ref{Any}(nothing)
const _LATE_MODS = Ref{Set{Module}}(Set{Module}())
const _MODS0 = Ref{Set{Module}}(Set{Module}())
_snap!() = (_BEFORE[] = _cis(); _MODS0[] = Set{Module}(values(Base.loaded_modules)); nothing)
_split!() = (_LATE_MODS[] = setdiff(Set{Module}(values(Base.loaded_modules)), _MODS0[]); nothing)
_new() = (a = _cis(); [ci for ci in a if !(ci in _BEFORE[])])
_mi(ci) = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
function _count(io = stdout)
    new = _new()
    owners = Dict{Any,Int}(); mods = Dict{Tuple{Any,Module},Int}()
    for ci in new
        owners[ci.owner] = get(owners, ci.owner, 0) + 1
        mi = _mi(ci)
        mod = mi.def isa Method ? Base.moduleroot(mi.def.module) : Core
        k = (ci.owner, mod); mods[k] = get(mods, k, 0) + 1
    end
    println(io, "C new CodeInstances ", length(new), " by owner ", owners,
            "; naming Main ", count(ci -> _names_main(_mi(ci).specTypes), new))
    for ((o, m), n) in sort!(collect(mods); by = last, rev = true)[1:min(end, 25)]
        println(io, "C   ", rpad(string(o), 26), rpad(string(m), 28), n)
    end
end
function _record(stmts::String)
    late(T) = _mentions(T, m -> Base.moduleroot(m) in _LATE_MODS[])
    parts = [(plain = Any[], facts = Any[], checks = Any[]) for _ in 1:2]
    total = 0; named = 0; other = 0
    for ci in _new()
        total += 1
        mi = _mi(ci); mi.def isa Method || continue
        T = mi.specTypes
        if _names_main(T); named += 1; continue; end
        k = (late(T) || Base.moduleroot(mi.def.module) in _LATE_MODS[]) ? 2 : 1
        ci.owner === :facts ? push!(parts[k].facts, T) : ci.owner === nothing ? push!(parts[k].plain, T) : (other += 1)
    end
    nchecks = 0
    for (id, m) in Base.loaded_modules
        id.name == "TraitWorld" || continue
        for sig in getglobal(m, :_CHECKED_IN_SESSION)
            _names_main(sig) && continue
            push!(parts[late(sig) ? 2 : 1].checks, sig); nchecks += 1
        end
    end
    # each type serialized on its own, so a type whose module the cache's build does not load is skipped alone
    ser(x) = (io = IOBuffer(); Serialization.serialize(io, x); take!(io))
    for k in 1:2
        p = parts[k]
        Serialization.serialize(replace(stmts, r"\.jls$" => "-$k.jls"),
            (plain = map(ser, unique(p.plain)), facts = map(ser, unique(p.facts)), checks = map(ser, unique(p.checks))))
        println("R part ", k, ": plain ", length(unique(p.plain)), ", facts ", length(unique(p.facts)), ", checks ", length(unique(p.checks)))
    end
    println("R new CodeInstances ", total, "; naming Main ", named, "; other owners ", other, "; checks ", nchecks)
end
using Serialization
