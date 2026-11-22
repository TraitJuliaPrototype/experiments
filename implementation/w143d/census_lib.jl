# W-143d (E-540): W-143c's census library, unchanged; W-143c (E-535): the census's library, copied from `../w157/census_lib.jl` and adapted to the head
# (`next` cf0f039f51). The deep class is the G2 bit (compiler §3.2); the culprits are found by the build's
# predicate (`Compiler.edges_satisfy_g2`) replayed edge by edge; their kinds; each own instance's cone.
# What changed against W-157's copy (README, "The tool's changes"):
#   - the own modules and the session's work are chosen by CENSUS_OWN and CENSUS_WORK (`table`, `ode`);
#   - a callee named by its MethodInstance whose code names the caller back is a member of the caller's
#     inference cycle (the predicate judges the cycle as one, `is_own`): no fault of its own (kind `:cycmi`);
#   - the check of the replay: instances with the bit that have a fault of their own (must be 0);
#   - the dispatch edges that are facts only as calls of an owner-only function (compiler §1.2), counted.
# The bits' masks (`JL_CI_FLAGS_G2` 0x10, `JL_CI_FLAGS_FACTS` 0x20) and the edges' forms (`CallSigBackedge`,
# a binding, a membership's instance, an absence signature) are the head's, as in W-157's copy.
const G2, FACTS = 0x10, 0x20
const C = Base.Compiler
const CORE8 = (:CSV, :DataFrames, :Tables, :Parsers, :InlineStrings, :PooledArrays, :WeakRefStrings, :SentinelArrays)
const ODEOWN = (:TraitDifferentialEquations, :ODECore, :TraitArrayTools, :TraitRodas, :TraitNonlinearSolve, :TraitIndexing,
                :TraitImplicit, :TraitLinSolvers, :TraitNLSolvers)
const WORK = get(ENV, "CENSUS_WORK", "table")
const OWN = haskey(ENV, "CENSUS_OWN") ? Tuple(Symbol.(split(ENV["CENSUS_OWN"], ","))) : (WORK == "ode" ? ODEOWN : CORE8)
rootof(mi::Core.MethodInstance) = mi.def isa Method ? nameof(Base.moduleroot(mi.def.module)) : :none
rootof(ci::Core.CodeInstance) = rootof(ci.def)
valid(ci) = ci.max_world == typemax(UInt)
isfacts(ci) = (ci.flags & FACTS) != 0
bit(ci) = (ci.flags & G2) != 0
function tally()
    out = Core.CodeInstance[]
    Base.visit(Core.methodtable) do m
        nameof(Base.moduleroot(m.module)) in OWN || return
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
isimpl(@nospecialize(sig)) = C.is_absence_sig(sig)
ismembmi(mi::Core.MethodInstance) = C.is_membership_mi(mi)
# whether some code of `e` names `mi` (by instance or by code) among its edges: `e` and `mi` are one cycle
names_back(e::Core.MethodInstance, mi::Core.MethodInstance) =
    any(c -> any(x -> x === mi || (x isa Core.CodeInstance && x.def === mi), c.edges), micode(e))
# the instance's own faults, by the build's predicate (compiler §3.2) replayed edge by edge; a callee
# without the bit is no fault of its own (it is followed).
struct Fault; kind::Symbol; sig::Any; end   # :nofact (a dispatch edge), :nomethod (no match), :mi (by instance)
function faults(ci::Core.CodeInstance)
    mi = C.get_ci_mi(ci); out = Fault[]
    for e in ci.edges
        if e isa Core.MethodInstance
            (e === mi || ismembmi(e)) && continue
            names_back(e, mi) && continue          # a member of the caller's cycle (`is_own`)
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
# a fact signature only as a call of an owner-only function (compiler §1.2)
fact_but_owner(@nospecialize(T)) = T isa DataType && (isdispatchtuple(T) || C.fact_splits_ok(T, C.FACT_UNION_SPLITTING) ||
    C.vararg_fact(T) || (T <: Tuple && length(T.parameters) >= 1 && C.is_closure_type(T.parameters[1]) && C.kinds_ok(T.parameters)))
function owner_only_edges(ci::Core.CodeInstance)
    n = 0
    for (invokesig, item) in C.ForwardToBackedgeIterator(ci.edges)
        s = item isa Core.MethodTable ? invokesig :
            item isa Core.MethodInstance && !ismembmi(item) && (invokesig === nothing || invokesig isa C.CallSigBackedge) ?
                (invokesig isa C.CallSigBackedge ? invokesig.sig : item.specTypes) : nothing
        s === nothing && continue
        s isa DataType && C.owner_only_call(s) && !fact_but_owner(s) && (n += 1)
    end
    n
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

# the session's work: E-392's table work (the forks' or upstream's CSV and DataFrames, `csv`), or the ODE
# port's (Lorenz with Tsit5, Robertson with Rodas5: `../w135/apps/ode.jl`'s `main` without its printing)
function session_work(csv)
    if WORK == "table"
        @eval Main using CSV, DataFrames
        return @eval Main () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                     g = combine(groupby(df, names(df)[end]), c => sum); string(hash(repr((d, first(s, 3), g))); base = 16))
    elseif WORK == "ode"
        @eval Main begin
            using TraitWorld, TraitDifferentialEquations; const ODE = TraitDifferentialEquations
            last1(s) = ODE.ODECore.state(s, length(ODE.ODECore.times(s)))[1]
            function lorenz!(du, u, p, t)
                s, r, b = p
                du[1] = s * (u[2] - u[1]); du[2] = u[1] * (r - u[3]) - u[2]; du[3] = u[1] * u[2] - b * u[3]
                nothing
            end
            function robertson!(du, u, p, t)
                du[1] = -0.04u[1] + 1e4 * u[2] * u[3]
                du[2] = 0.04u[1] - 1e4 * u[2] * u[3] - 3e7 * u[2]^2
                du[3] = 3e7 * u[2]^2
                nothing
            end
        end
        return @eval Main () -> begin
            a = ODE.solve(ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3]), ODE.Tsit5();
                          saveat = collect(range(0.0, 20.0; length = 2001)), reltol = 1e-6, abstol = 1e-8)
            b = ODE.solve(ODE.ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.0]), ODE.Rodas5();
                          saveat = exp10.(range(-5, 5; length = 201)), reltol = 1e-6, abstol = 1e-8)
            string(round(last1(a); sigdigits = 6), " ", round(last1(b); sigdigits = 6))
        end
    else
        error("CENSUS_WORK: table or ode")
    end
end

"""
The session (the work twice) and its classes: the own instances, the reach below them, the culprits with
their faults and kinds, each own facts instance's cone.
"""
function census_session(csv)
    w = session_work(csv)
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
    bitfault = Core.CodeInstance[]    # the replay's check: with the bit and a fault of its own (must be none)
    for ci in reach
        if bit(ci)
            isempty(faults(ci)) || push!(bitfault, ci)
            continue
        end
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
    return (; w, d1, image, made, own, ownset = IdSet{Any}(own), factsown, reach, rev, fcache, culprit, nofault, outside, cone,
            incone, bitfault)
end
pc(n, d) = string(n, " (", d == 0 ? 0 : round(n / d * 100; digits = 1), " %)")
