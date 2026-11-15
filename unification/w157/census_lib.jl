# W-157: the census's library (`census.jl`, `diag/*.jl`): the deep class (the G2 bit, compiler §3.2), the
# culprits by the build's predicate replayed edge by edge, their kinds, and each own instance's cone.
const G2, FACTS = 0x10, 0x20
const C = Base.Compiler
const CORE8 = (:CSV, :DataFrames, :Tables, :Parsers, :InlineStrings, :PooledArrays, :WeakRefStrings, :SentinelArrays)
rootof(mi::Core.MethodInstance) = mi.def isa Method ? nameof(Base.moduleroot(mi.def.module)) : :none
rootof(ci::Core.CodeInstance) = rootof(ci.def)
valid(ci) = ci.max_world == typemax(UInt)
isfacts(ci) = (ci.flags & FACTS) != 0
bit(ci) = (ci.flags & G2) != 0
function tally()
    out = Core.CodeInstance[]
    Base.visit(Core.methodtable) do m
        nameof(Base.moduleroot(m.module)) in CORE8 || return
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                valid(ci) && ci.owner === nothing && push!(out, ci)
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    out
end
# the valid CodeInstances of Julia's owner a MethodInstance has now (an edge that names it reaches them)
function micode(mi::Core.MethodInstance)
    out = Core.CodeInstance[]
    isdefined(mi, :cache) || return out
    c = mi.cache
    while true; valid(c) && c.owner === nothing && push!(out, c); isdefined(c, :next) || break; c = c.next; end
    out
end
isimpl(@nospecialize(sig)) = (b = Base.unwrap_unionall(sig); b isa DataType && length(b.parameters) == 3 && b.parameters[1] === typeof(Core.implements))
ismembmi(mi::Core.MethodInstance) = (m = mi.def; m isa Method && isimpl(m.sig))
# the instance's own faults, by the build's predicate (compiler §3.2) replayed edge by edge; a callee
# without the bit is no fault of its own (it is followed). `mis`: the callees it names by instance alone.
struct Fault; kind::Symbol; sig::Any; end   # :nofact (a dispatch edge), :nomethod (no match), :mi (by instance)
function faults(ci::Core.CodeInstance)
    mi = C.get_ci_mi(ci); out = Fault[]
    for e in ci.edges
        if e isa Core.MethodInstance
            (e === mi || ismembmi(e)) && continue
            push!(out, Fault(:mi, e))
        end
    end
    for (invokesig, item) in C.ForwardToBackedgeIterator(ci.edges)
        if item isa Core.MethodTable
            (C.is_fact_sig(invokesig) || isimpl(invokesig)) || push!(out, Fault(:nomethod, invokesig))
        elseif item isa Core.MethodInstance
            ismembmi(item) && continue
            (invokesig === nothing || invokesig isa C.CallSigBackedge) || continue
            s = invokesig isa C.CallSigBackedge ? invokesig.sig : item.specTypes
            C.is_fact_sig(s) || push!(out, Fault(:nofact, s))
        end
    end
    out
end
# the dependency graph below the own code: CodeInstance edges, and an edge by instance to its code now
function succ(ci::Core.CodeInstance)
    out = Core.CodeInstance[]
    for e in ci.edges
        if e isa Core.CodeInstance
            e === ci || push!(out, e)
        elseif e isa Core.MethodInstance && e !== ci.def && !ismembmi(e)
            append!(out, micode(e))
        end
    end
    out
end
# the kinds of the census (W-157): the first that applies
const JOINS = (:typejoin, :promote_typejoin, :typesplit, :_promote_typesubtract, :promote_type, :promote_rule,
               :promote_result, :_typejoin, :promote_typejoin_union, :typejoin_union_tuple, :tuple_type_head, :tmerge)
const TASKS = (:wait, :notify, :yieldto, :try_yieldto, :lock, :unlock, :trylock, :_wait, :_wait2, :schedule, :yield,
               :enq_work, :wait_forever, :sleep, :put!, :take!, :fetch, :_trywait, :errormonitor, :Timer, :Condition,
               :ReentrantLock, :GenericCondition, :task_done_hook, :Task, :ensure_rescheduled, :islocked, :close,
               :notify_error, :sync_end, :istaskdone, :istaskstarted, :istaskfailed, :trypoptask, :_trywait)
fname(@nospecialize(sig)) = (b = Base.unwrap_unionall(sig); b isa DataType && !isempty(b.parameters) ? b.parameters[1] : nothing)
fnname(@nospecialize(f)) = f isa DataType && isdefined(f, :instance) && f.instance isa Function ? nameof(f.instance) : nothing
# a kind: a type whose values are types, other than `Type{T}` with `T` known (compiler §1.2)
iskind(@nospecialize(t)) = t isa Type && t !== Union{} && t <: Type && !(t isa DataType && t.name === Type.body.name && !(t.parameters[1] isa TypeVar))
args(@nospecialize(sig)) = (b = Base.unwrap_unionall(sig); b isa DataType ? b.parameters[2:end] : Any[])
isanycontainer(@nospecialize(t)) = t isa Type && t !== Union{} &&
    (t <: AbstractArray{Any} || t <: AbstractDict{Any} || t <: (AbstractDict{K, Any} where K) || t <: AbstractSet{Any})
isexc(@nospecialize(f)) = f isa DataType && f.name === Type.body.name && f.parameters[1] isa DataType && f.parameters[1] <: Exception
function kindof(ci::Core.CodeInstance, fs::Vector{Fault})
    mi = ci.def; m = mi.def::Method
    any(f -> f.kind === :mi, fs) && all(f -> f.kind === :mi, fs) && return :by_instance
    sigs = Any[f.sig for f in fs if f.kind !== :mi]
    fns = Any[fname(s) for s in sigs]
    # an error path: the instance only throws, or builds an exception, or calls a constructor of one
    (ci.rettype === Union{} || isexc(fname(mi.specTypes)) || any(isexc, fns) || m.name in (:throw_boundserror, :string_index_err, :throw_inexacterror)) && return :error_path
    (m.name in JOINS || any(f -> fnname(f) in JOINS, fns)) && return :type_join
    (m.name in TASKS || any(f -> fnname(f) in TASKS, fns)) && return :task_lock
    # a constructor called with a value of a kind
    any(i -> (f = fns[i]; f isa DataType && f.name === Type.body.name && any(iskind, args(sigs[i]))), eachindex(sigs)) && return :ctor_kind
    (any(isanycontainer, args(mi.specTypes)) || any(s -> any(isanycontainer, args(s)), sigs)) && return :any_container
    any(s -> any(iskind, args(s)), sigs) && return :introspection
    return :other
end
mname(ci) = (m = ci.def.def::Method; string(m.module, ".", m.name))

"""
The session of E-392 (the forks' or upstream's CSV and DataFrames, the work twice) and its classes: the own
instances, the reach below them, the culprits with their faults and kinds, each own facts instance's cone.
"""
function census_session(csv)
    @eval Main using CSV, DataFrames
    w = @eval Main () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                     g = combine(groupby(df, names(df)[end]), c => sum); string(hash(repr((d, first(s, 3), g))); base = 16))
    image = tally()
    d1 = Base.invokelatest(w); Base.invokelatest(w)
    seen0 = IdSet{Any}(image); made = [ci for ci in tally() if !(ci in seen0)]
    own = vcat(image, made); factsown = filter(isfacts, own)
    reach = IdSet{Core.CodeInstance}(); st = Core.CodeInstance[own...]
    rev = IdDict{Any,Vector{Any}}()
    while !isempty(st)
        ci = pop!(st); ci in reach && continue; push!(reach, ci)
        for c in succ(ci); push!(get!(rev, c, Any[]), ci); c in reach || push!(st, c); end
    end
    fcache = IdDict{Core.CodeInstance,Vector{Fault}}(); culprit = IdDict{Core.CodeInstance,Symbol}()
    for ci in reach
        bit(ci) && continue
        fs = faults(ci); fcache[ci] = fs
        isempty(fs) || (culprit[ci] = kindof(ci, fs))
    end
    # without the bit, no fault of its own and every callee with the bit: a member of an inference cycle
    # decided as one whose fault the walk does not reach, or a bit not set
    nofault = [ci for ci in reach if !bit(ci) && !haskey(culprit, ci) && all(bit, succ(ci))]
    for ci in nofault; culprit[ci] = :cycle_or_unset; end
    function conef(x)
        v = IdSet{Any}(); s = Core.CodeInstance[x]; c = Core.CodeInstance[]
        while !isempty(s)
            y = pop!(s); y in v && continue; push!(v, y)
            haskey(culprit, y) && push!(c, y)
            for z in succ(y); bit(z) || z in v || push!(s, z); end
        end
        c
    end
    outside = [ci for ci in factsown if !bit(ci)]
    cone = IdDict{Core.CodeInstance,Vector{Core.CodeInstance}}()
    for x in outside; cone[x] = conef(x); end
    incone = IdDict{Core.CodeInstance,Int}(); for x in outside, y in cone[x]; incone[y] = get(incone, y, 0) + 1; end
    return (; w, d1, image, made, own, ownset = IdSet{Any}(own), factsown, reach, rev, fcache, culprit, nofault, outside, cone, incone)
end
pc(n, d) = string(n, " (", d == 0 ? 0 : round(n / d * 100; digits = 1), " %)")
