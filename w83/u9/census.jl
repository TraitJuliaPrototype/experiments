# E-259 (U9): the guards of option (e) of open issue 136, counted over the code a session compiled.
#
#     include("census.jl"); U9Census.run("<label>")       # at the end of a session, in its process
#
# The model (open issue 136 (e)): a bounded method `f(x::X)` is a Julia method at `X`. A compiled call
# `f(a::A…)` at concrete argument types
#   - folds a positive membership (`Aᵢ ∈ X` now): static dispatch to the bounded method;
#   - carries a guard where a bounded method `b` that does not apply now would apply after a later
#     membership (`Aᵢ ∉ X`, `X` open, `Aᵢ` not one of Core's kinds) and would beat the method selected
#     now: the most specific plain method `m₀` (case `fallback`), a bounded method on a less specific
#     set (case `subtrait`), or none (case `methoderror`);
#   - specificity per position: a type named in the argument's own definition (a plain method's type
#     other than `Any`) before a set (C7), a set before `Any`; between sets, a subtrait before its
#     supertrait; between plain types, subtyping.
# Read from TraitWorld's registries: the bounded methods (workers, with their bounds per position, as
# U5 read them) and the defaults of operations (a bounded method of the operation at its trait); the
# plain methods of each function from its method table without the entries, the workers and the
# tagged untyped fallbacks (a tagged fallback counts as the plain method it stands for).
# The compiled call sites: every CodeInstance holding an edge to a method instance of such a function
# (the backedges, session code and image code alike), re-inferred unoptimized (by facts for code of
# the facts owner); in it, every call of such a function with its argument types, whether it lies in
# a cycle of the caller's control-flow graph, and its inferred result.
module U9Census

const TW = Base.loaded_modules[only(k for k in keys(Base.loaded_modules) if k.name == "TraitWorld")]
const CC = Base.Compiler

# --- modules and functions --------------------------------------------------------------------------
function allmods()
    seen = Base.IdSet{Module}(); out = Module[]
    function walk(m::Module)
        m in seen && return
        push!(seen, m); push!(out, m)
        for n in names(m; all = true, imported = false)
            isdefined(m, n) || continue
            v = try getglobal(m, n) catch; continue end
            v isa Module && v !== m && parentmodule(v) === m && walk(v)
        end
    end
    for (_, m) in Base.loaded_modules; walk(m); end
    walk(Main)
    return out
end

fam(X) = try TW._family(X) catch; X end
closure(F) = try Any[fam(Y) for Y in TW.trait_closure(F)] catch; Any[F] end
famname(F) = F === :hypo ? "HypotheticalOpenSet" : sprint(show, F)

"The trait families a worker's argument is bounded by (minimal), `:callable`, or `nothing` (as U5)."
function bound_at(p)
    q = Base.unwrap_unionall(p)
    q isa Core.TypeofVararg && (q = Base.unwrap_unionall(q.T))
    if q isa DataType && q.name === Base.typename(TW.TObj)
        L = TW._tobj_lb(q)
        L === nothing && return nothing
        Fs = unique(Any[fam(Y) for Y in Base.uniontypes(L) if TW.is_trait(Y)])
        return Any[F for F in Fs if !any(G -> G != F && any(==(F), closure(G)), Fs)]
    elseif q isa DataType && (q.name === Base.typename(TW.CObj) || q.name === Base.typename(TW.CMulti))
        return :callable
    end
    return nothing
end
isworker(m::Method) = any(p -> bound_at(p) !== nothing, Base.unwrap_unionall(m.sig).parameters[2:end])
istagged(m::Method) = TW._is_tagged(m)

function trait_functions(mods)
    fs = Any[]
    for tm in mods
        isdefined(tm, :__trait_module__) && isdefined(tm, :__tw_entries__) || continue
        ks = Any[collect(keys(tm.__tw_entries__))...]
        isdefined(tm, :__tw_extended__) && append!(ks, collect(tm.__tw_extended__))
        for k in ks
            isdefined(k[1], k[2]) || continue
            f = getglobal(k[1], k[2])
            any(g -> g === f, fs) || push!(fs, f)
        end
    end
    return fs
end

# --- bounded and plain methods ------------------------------------------------------------------------
"A position of a method: `(:set, families)`, `(:callable,)` or `(:plain, T)` (T an upper bound)."
ubof(p) = (p isa TypeVar ? ubof(p.ub) : p isa Core.TypeofVararg ? ubof(p.T) : p)

struct BM
    f::Any
    m::Union{Method,Nothing}
    pos::Vector{Any}
    va::Bool
    ret::Any            # the declared result, `Any` where none is declared
    origin::Symbol      # :worker, :default, :hypo
    name::String
end
struct PM
    m::Method
    pos::Vector{Any}
    va::Bool
    tagged::Bool
    sig::Any            # the signature it stands for (a tagged fallback without its tag)
end

"""
The declared result of a method (`f(…)::R = …`): Julia lowers it to `v isa R || (v = typeassert(convert(R, v), R))`
before each return, so the `R` that both an `isa` and a `typeassert` of the body name. `Any` where none is declared.
"""
function declared_ret(m::Method)
    src = try Base.uncompressed_ast(m) catch; return Any end
    function resolve(x, depth = 0)
        depth > 8 && return nothing
        x isa Core.SSAValue && return resolve(src.code[x.id], depth + 1)
        x isa GlobalRef && return (try getglobal(x.mod, x.name) catch; nothing end)
        x isa QuoteNode && return x.value
        x isa Type && return x
        if x isa Expr && x.head === :call
            vs = Any[resolve(a, depth + 1) for a in x.args]
            any(isnothing, vs) && return nothing
            return try vs[1](vs[2:end]...) catch; nothing end
        end
        return nothing
    end
    isref(st, name) = st isa Expr && st.head === :call && length(st.args) == 3 && st.args[1] isa GlobalRef &&
                      st.args[1].mod === Core && st.args[1].name === name
    asserted = Any[]; tested = Any[]
    for st in src.code
        st isa Expr && st.head === :(=) && (st = st.args[2])
        isref(st, :typeassert) && push!(asserted, st.args[3])
        isref(st, :isa) && push!(tested, st.args[3])
    end
    for a in asserted
        a in tested || continue
        R = resolve(a)
        R isa Type && return R
        return :declared_unresolved
    end
    return Any
end

function bounded_methods(f)
    out = BM[]
    for m in methods(f)
        isworker(m) || continue
        ps = Base.unwrap_unionall(m.sig).parameters
        pos = Any[]
        for p in ps[2:end]
            b = bound_at(p)
            push!(pos, b === nothing ? (:plain, ubof(p)) : b === :callable ? (:callable,) : (:set, b))
        end
        va = !isempty(ps) && ps[end] isa Core.TypeofVararg
        push!(out, BM(f, m, pos, va, declared_ret(m), :worker,
                      string(m.module, ".", m.name, "(", join([p[1] === :set ? join(famname.(p[2]), "+") : p[1] === :callable ? "Callable" : string(p[2]) for p in pos], ", "), ")")))
    end
    return out
end

function plain_methods(f)
    out = PM[]
    for m in methods(f)
        (isworker(m) || TW._is_entry(m)) && continue
        b = Base.unwrap_unionall(m.sig)
        ps = b.parameters
        tg = istagged(m)
        rest = tg ? ps[3:end] : ps[2:end]
        sig = tg ? Base.rewrap_unionall(Tuple{ps[1], rest...}, m.sig) : m.sig
        push!(out, PM(m, Any[(:plain, ubof(p)) for p in rest], !isempty(rest) && rest[end] isa Core.TypeofVararg, tg, sig))
    end
    return out
end

"The defaults of operations: `(f, trait family, key)` for each `has_default(::Type{Y}, ::Val{key}) = true`."
function op_defaults()
    out = Any[]
    for m in methods(TW.has_default)
        ps = Base.unwrap_unionall(m.sig).parameters
        length(ps) == 3 || continue
        Ty = ps[2]; V = ps[3]
        (Ty isa DataType && Ty <: Type && V isa DataType && V <: Val) || continue
        Y = Ty.parameters[1]; key = V.parameters[1]
        Y isa TypeVar && continue
        f = try Base.invokelatest(TW.op_function, Y, Val(key)) catch; continue end
        # the declared result, read at the erased key (a type naming `Self` or an open parameter reads `Any`)
        R = Any
        for r in methods(TW.op_ret)
            q = Base.unwrap_unionall(r.sig).parameters
            length(q) == 5 || continue
            (q[2] == Type{Y} && q[3] == Val{key}) || continue
            N = q[5] isa DataType ? q[5].parameters[1] : continue
            N isa Int || continue
            R = try Base.invokelatest(TW.op_ret, Y, Val(key), TW.ErasedKey{Tuple{},Nothing}, Val(N)) catch; Any end
            R isa Type || (R = Any)
            break
        end
        push!(out, (f, fam(Y), key, R))
    end
    return out
end

posat(pos::Vector{Any}, va::Bool, i::Int) = i <= length(pos) ? pos[i] : va ? pos[end] : nothing

# --- membership ---------------------------------------------------------------------------------------
"Core's kinds and type values: never late members (E-255)."
corekind(@nospecialize(A)) = A <: Type || A <: Module || A <: Core.TypeName || A <: Core.Builtin || A <: Core.TypeVar ||
                             A <: Core.OpaqueClosure || A <: GenericMemory || A <: GenericMemoryRef || A <: Core.MethodInstance
const MEMB = IdDict{Any,IdDict{Any,Bool}}()
function member(@nospecialize(A), F)
    F === :hypo && return false
    d = get!(() -> IdDict{Any,Bool}(), MEMB, A)
    get!(d, F) do
        A <: TW.Dynamic && return (try TW.conforms(A, F) catch; false end)
        try Base.invokelatest(TW.conforms, A, F)::Bool catch; false end
    end
end
"Membership of argument `a` (resolved) in a position: `:yes`, `:no` (cannot join late), `:later` (an open set it is not a member of yet)."
function pos_member(a, p)
    kind, S, carried = a
    T = S === nothing ? Any : S
    p[1] === :plain && return (S === nothing ? true : S <: p[2]) ? :yes : :no
    p[1] === :callable && return :yes
    all(F -> F in carried || (S !== nothing && member(S, F)), p[2]) && return :yes
    S !== nothing && corekind(S) && return :no
    return :later
end

"""
What an argument type stands for under the model: a trait object (`TObj`, inside bounded code) is a value
of its key's receiver type `S` (`nothing` where the key has no receiver), known to be a member of the traits
it carries; `Dynamic{X}`, `Kept{X}`, `Compiled{X}` are run-time values (`:dynamic`).
"""
function resolve_arg(@nospecialize(A))
    (A <: TW.Dynamic || A <: TW.Kept || A <: TW.Compiled) && A !== Union{} && return (:dynamic, A, Any[])
    if A isa DataType && A.name === Base.typename(TW.TObj)
        carried = Any[]
        try
            for Y in Base.uniontypes(TW._decode_traits(A.parameters[1]))
                append!(carried, closure(fam(Y)))
            end
        catch
        end
        S = nothing
        V = A.parameters[2]
        if V isa DataType && V <: Tuple && !isempty(V.parameters)
            v = V.parameters[1]
            if v isa DataType && v <: TW.AbstractView && length(v.parameters) >= 3
                K = v.parameters[3]
                if K isa DataType && K <: TW.ErasedKey
                    return (:dynamic, A, Any[])          # an erased key: a `Dynamic` value's trait object
                elseif K isa DataType && K <: TW.Key
                    I = K.parameters[1]
                    S = I === Nothing ? nothing : I
                elseif K isa Type
                    S = K
                end
            end
        end
        return (:tobj, S, carried)
    end
    return (:plain, A, Any[])
end

# --- sealed sets: every membership declared at the member's definition or in its own package proper (U5) ---
typenames_of(T) = (T = Base.unwrap_unionall(T); T isa Union ? vcat(typenames_of(T.a), typenames_of(T.b)) :
                   T isa DataType ? Core.TypeName[T.name] : T isa TypeVar ? typenames_of(T.ub) : Core.TypeName[])
isext(m::Module) = TW._extension_parent(Base.moduleroot(m)) !== nothing
"Per trait family: the kinds of its memberships (U5's classification: `conformance` methods)."
function membership_kinds()
    out = IdDict{Any,Vector{Symbol}}()
    for m in methods(TW.conformance)
        sig = Base.unwrap_unionall(m.sig); ps = sig.parameters
        length(ps) == 3 || continue
        A = ps[2]
        (A isa DataType && A.name === Base.typename(TW.As)) || continue
        X = A.parameters[1]; Tp = ps[3]
        Tp === Any && continue
        generic = Tp isa TypeVar
        T = generic ? Base.rewrap_unionall(Tp.ub, m.sig) : Base.rewrap_unionall(Tp, m.sig)
        D = m.module; Do = TW.owner(D); tns = typenames_of(T)
        own = !isempty(tns) && all(tn -> TW.owns(Do, TW.owner(tn.module)), tns)
        pown = !generic && !own && (try TW._owns(Do, T) catch; false end)
        kind = isext(D) ? :extension : generic ? (own ? :generic_own_ub : :generic) : own ? :by_owner : pown ? :by_owner_param :
               T isa UnionAll ? :family_foreign : :foreign_type
        push!(get!(() -> Symbol[], out, fam(X)), kind)
    end
    return out
end
const MKINDS = Ref{Any}(nothing)
"A set whose memberships are all the member's own (at its definition, or in its package proper; U5's refined reading, no extension): a variant of (e) would fold its negatives."
function sealed(F)
    F === :hypo && return false
    MKINDS[] === nothing && (MKINDS[] = membership_kinds())
    ks = Symbol[]
    for (G, v) in MKINDS[]
        # members of F: memberships of F and of its subtraits
        any(==(F), closure(G)) && append!(ks, v)
    end
    return all(k -> k in (:by_owner, :by_owner_param, :generic_own_ub), ks)
end
"Whether every position at which guard `b` waits is a sealed set (the guard folds under the variant)."
function guard_sealed(b::BM, A::Vector{Any})
    R = Any[resolve_arg(a) for a in A]
    for i in eachindex(A)
        p = posat(b.pos, b.va, i)
        p === nothing && continue
        pos_member(R[i], p) === :later || continue
        all(F -> sealed(F) || (F in R[i][3]) || (R[i][2] !== nothing && member(R[i][2], F)), p[2]) || return false
    end
    return true
end

# --- specificity (C7: declared supertypes first, then sets, then `Any`) -----------------------------
anyish(@nospecialize(T)) = T === Any || (T isa Type && Any <: T)
"Compare position `p` of method 1 with `q` of method 2: :better, :equal, :worse, :incomparable."
function cmp_pos(p, q)
    k1 = p === nothing ? :plainany : p[1] === :plain ? (anyish(p[2]) ? :plainany : :plaindecl) : p[1] === :callable ? :plainany : :set
    k2 = q === nothing ? :plainany : q[1] === :plain ? (anyish(q[2]) ? :plainany : :plaindecl) : q[1] === :callable ? :plainany : :set
    rank = Dict(:plainany => 0, :set => 1, :plaindecl => 2)
    if k1 === :set && k2 === :set
        F1, F2 = p[2], q[2]
        c1 = all(G -> any(F -> G in closure(F), F1), F2)   # p's sets imply q's
        c2 = all(G -> any(F -> G in closure(F), F2), F1)
        return c1 && c2 ? :equal : c1 ? :better : c2 ? :worse : :incomparable
    elseif k1 === :set || k2 === :set
        return rank[k1] > rank[k2] ? :better : rank[k1] < rank[k2] ? :worse : :equal
    else
        T1 = p === nothing || p[1] === :callable ? Any : p[2]
        T2 = q === nothing || q[1] === :callable ? Any : q[2]
        s1 = T1 <: T2; s2 = T2 <: T1
        return s1 && s2 ? :equal : s1 ? :better : s2 ? :worse : :incomparable
    end
end
"Whether method 1 (positions pos1) beats method 2 at an `n`-argument call: :beats, :loses, :ambiguous, :same."
function beats(pos1, va1, pos2, va2, n)
    b = false; w = false; inc = false
    for i in 1:n
        c = cmp_pos(posat(pos1, va1, i), posat(pos2, va2, i))
        c === :better && (b = true)
        c === :worse && (w = true)
        c === :incomparable && (inc = true)
    end
    (inc || (b && w)) && return :ambiguous
    b && return :beats
    w && return :loses
    return :same
end

# --- the decision at one call -------------------------------------------------------------------------
isconcreteish(@nospecialize(A)) = isconcretetype(A) || (A isa DataType && A <: Type && isconcretetype(typeof(A)) && !(A isa UnionAll)) || Base.isType(A)

"The positions at which a later membership would make `b` apply: `i:Aᵢ∉X` for each."
function laterpos(b::BM, A::Vector{Any})
    R = Any[resolve_arg(a) for a in A]
    out = String[]
    for i in eachindex(A)
        p = posat(b.pos, b.va, i)
        p === nothing && continue
        pos_member(R[i], p) === :later && push!(out, string(i, ":", R[i][2] === nothing ? A[i] : R[i][2], "∉", join(famname.(p[2]), "+")))
    end
    return join(out, ",")
end

struct Decision
    case::Symbol            # :guard_fallback, :guard_subtrait, :guard_methoderror, :fold_positive, :plain, :methoderror_closed, :ambiguous_now, :ambiguous_later
    sel::Any                # the selected method now (PM, BM or nothing)
    guards::Vector{BM}      # the bounded methods that could win later
end

function decide(f, A::Vector{Any}, bms::Vector{BM}, pms::Vector{PM})
    n = length(A)
    R = Any[resolve_arg(a) for a in A]
    tt = Tuple{Core.Typeof(f), Any[(r[1] === :tobj && r[2] !== nothing) ? r[2] : A[i] for (i, r) in enumerate(R)]...}
    app_plain = PM[p for p in pms if (try tt <: p.sig catch; false end)]
    now = BM[]; later = BM[]
    for b in bms
        (length(b.pos) == n || (b.va && n >= length(b.pos) - 1)) || continue
        st = [pos_member(R[i], posat(b.pos, b.va, i)) for i in 1:n]
        any(==(:no), st) && continue
        all(==(:yes), st) ? push!(now, b) : push!(later, b)
    end
    # the plain method selected now
    m0 = nothing
    if !isempty(app_plain)
        m0 = app_plain[1]
        for p in app_plain[2:end]
            Base.morespecific(p.sig, m0.sig) && (m0 = p)
        end
        if any(p -> p !== m0 && !Base.morespecific(m0.sig, p.sig) && !(p.sig <: m0.sig && m0.sig <: p.sig), app_plain)
            # ambiguous among plain methods (or a tagged fallback beside the method it shadows): keep the most specific by Julia
            m0 = m0
        end
    end
    # the selection among m0 and the bounded methods that apply now
    sel = m0
    selpos = m0 === nothing ? nothing : m0.pos; selva = m0 === nothing ? false : m0.va
    amb = false
    for b in now
        if sel === nothing
            sel = b; selpos = b.pos; selva = b.va; continue
        end
        r = beats(b.pos, b.va, selpos, selva, n)
        if r === :beats
            sel = b; selpos = b.pos; selva = b.va
        elseif r === :ambiguous
            amb = true
        end
    end
    amb && return Decision(:ambiguous_now, sel, BM[])
    gs = BM[]; ambl = false
    for b in later
        if sel === nothing
            push!(gs, b)
        else
            r = beats(b.pos, b.va, selpos, selva, n)
            r === :beats && push!(gs, b)
            r === :ambiguous && (ambl = true)
        end
    end
    if !isempty(gs)
        case = sel === nothing ? :guard_methoderror : sel isa BM ? :guard_subtrait : :guard_fallback
        return Decision(case, sel, gs)
    end
    ambl && return Decision(:ambiguous_later, sel, BM[])
    sel === nothing && return Decision(:methoderror_closed, nothing, BM[])
    return Decision(sel isa BM ? :fold_positive : :plain, sel, BM[])
end

# --- the result a guard would give ------------------------------------------------------------------
const RCACHE = IdDict{Any,Any}()
"The inferred result of plain method `p` at the call's types (by plain inference)."
function m0_result(f, p::PM, A)
    tt = p.tagged ? Tuple{Core.Typeof(f), TW.Untyped, A...} : Tuple{Core.Typeof(f), A...}
    get!(RCACHE, (p.m, tt)) do
        try
            r = ccall(:jl_type_intersection_with_env, Any, (Any, Any), tt, p.m.sig)::Core.SimpleVector
            interp = CC.NativeInterpreter()
            T = CC.typeinf_type(interp, p.m, r[1], r[2])
            T === nothing ? Any : T
        catch
            Any
        end
    end
end
function bm_result(b::BM, A)
    b.origin !== :default && return b.ret
    return b.ret
end

# --- the call sites ---------------------------------------------------------------------------------
"The callers of every method instance of `f`'s methods: CodeInstances (deduplicated by instance and owner)."
function callers!(acc::IdDict{Any,Any}, f)
    for m in methods(f)
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :backedges) || continue
            for e in mi.backedges
                e isa Core.CodeInstance || continue
                acc[e] = true
            end
        end
    end
end

function argtype(src::Core.CodeInfo, @nospecialize(x))
    if x isa Core.SSAValue
        return src.ssavaluetypes[x.id]
    elseif x isa Core.SlotNumber
        return src.slottypes[x.id]
    elseif x isa Core.Argument
        return src.slottypes[x.n]
    elseif x isa GlobalRef
        if isconst(x.mod, x.name)
            return Core.Const(getglobal(x.mod, x.name))
        end
        return Any
    elseif x isa QuoteNode
        return Core.Const(x.value)
    elseif x isa Expr || x isa Core.SlotNumber
        return Any
    end
    return Core.Const(x)
end
function fvalue(@nospecialize(t))
    t isa Core.Const && return (true, t.val)
    t isa Core.PartialStruct && return (false, nothing)
    T = CC.widenconst(t)
    T isa DataType && isdefined(T, :instance) && return (true, T.instance)
    return (false, nothing)
end

"The statements of `src` that lie in a cycle of its control-flow graph."
function loop_stmts(src::Core.CodeInfo)
    cfg = CC.compute_basic_blocks(src.code)
    nb = length(cfg.blocks)
    inloop = falses(nb)
    for b in 1:nb
        seen = falses(nb); stack = copy(cfg.blocks[b].succs)
        while !isempty(stack)
            s = pop!(stack)
            (s < 1 || s > nb) && continue
            if s == b; inloop[b] = true; break; end
            seen[s] && continue
            seen[s] = true
            append!(stack, cfg.blocks[s].succs)
        end
    end
    out = falses(length(src.code))
    for i in eachindex(src.code)
        b = CC.block_for_inst(cfg, i)
        out[i] = 1 <= b <= nb && inloop[b]
    end
    return out
end

struct Site
    caller::String
    callermod::String
    owner::Any
    f::Any
    A::Vector{Any}
    case::Symbol
    inloop::Bool
    sel::String
    guards::String
    r_today::Any
    r_m0::Any
    r_b::Any
    widen::Symbol            # :none, :covered (a declared result, a small join), :any
    inbounded::Bool          # the caller is a bounded method (a worker): trait code
    tobj::Symbol             # a trait object among the arguments: :none, :key (its receiver type known), :nokey
    sealedfold::Bool         # the guard folds if sets whose memberships are all the member's own fold negatives
    fbkind::Symbol           # what runs when the guard fails: :methoderror, :same_result (a default, or the bounded method's declared result), :real_fallback
end

selname(s) = s === nothing ? "-" : s isa BM ? s.name : string(s.m.module, ".", s.m.name, sprint(show, s.sig), s.tagged ? " [untyped fallback]" : "")

function census(label::String; hypo_show::Bool = true, out::String = joinpath(@__DIR__, "logs"))
    t0 = time()
    mods = allmods()
    fs = trait_functions(mods)
    BMS = IdDict{Any,Vector{BM}}()
    for f in fs
        BMS[f] = bounded_methods(f)
    end
    for (f, F, key, R) in op_defaults()
        v = get!(() -> BM[], BMS, f)
        push!(v, BM(f, nothing, Any[(:set, Any[F]), (:plain, Any)], true, R, :default, string(f, "(::", famname(F), ", …) [default of ", key, "]")))
    end
    if hypo_show
        v = get!(() -> BM[], BMS, Base.show)
        push!(v, BM(Base.show, nothing, Any[(:plain, IO), (:set, Any[:hypo])], false, Nothing, :hypo, "Base.show(::IO, ::HypotheticalOpenSet)"))
    end
    PMS = IdDict{Any,Vector{PM}}(f => plain_methods(f) for f in keys(BMS))
    open(joinpath(out, "$label-bounded.tsv"), "w") do io
        println(io, "function\tbounded_method\torigin\tdeclared_result\tfile_line\tplain_methods")
        for (f, v) in BMS, b in v
            println(io, f, "\t", b.name, "\t", b.origin, "\t", b.ret, "\t", b.m === nothing ? "-" : string(b.m.file, ":", b.m.line), "\t", length(PMS[f]))
        end
    end
    nbm = sum(count(b -> b.origin === :worker, v) for v in values(BMS); init = 0)
    ndef = sum(count(b -> b.origin === :default, v) for v in values(BMS); init = 0)
    println("== U9 census: ", label)
    println("julia ", Base.GIT_VERSION_INFO.commit_short, "; functions with bounded methods: ", length(BMS),
            " (bounded methods ", nbm, ", operation defaults ", ndef, hypo_show ? ", + hypothetical Base.show" : "", ")")
    acc = IdDict{Any,Any}()
    for f in keys(BMS)
        callers!(acc, f)
    end
    println("caller CodeInstances: ", length(acc))
    sites = Site[]
    ntop = 0; nfail = 0; nmach = 0; nsplat = 0; nnoncon = Dict{Any,Int}(); nreinf = 0
    seenmi = Set{Any}()
    for ci in keys(acc)
        ci = ci::Core.CodeInstance
        mi = ci.def
        mi isa Core.ABIOverride && (mi = mi.def)
        mi isa Core.MethodInstance || continue
        (mi, ci.owner) in seenmi && continue
        push!(seenmi, (mi, ci.owner))
        def = mi.def
        if !(def isa Method)
            ntop += 1; continue
        end
        if Base.moduleroot(def.module) === TW && def.module !== TW.BaseTraits
            nmach += 1; continue
        end
        interp = ci.owner === :facts ? CC.facts_interp(CC.NativeInterpreter()) : CC.NativeInterpreter()
        src = try CC.typeinf_code(interp, mi, false) catch; nothing end
        if !(src isa Core.CodeInfo)
            nfail += 1; continue
        end
        nreinf += 1
        loops = try loop_stmts(src) catch; falses(length(src.code)) end
        inb = isworker(def)
        cname = string(def.module, ".", def.name, " @ ", basename(string(def.file)), ":", def.line)
        for (i, st) in enumerate(src.code)
            st isa Expr && st.head === :call || continue
            isempty(st.args) && continue
            ok, g = fvalue(argtype(src, st.args[1]))
            ok || continue
            args = st.args[2:end]
            if g === Core.kwcall && length(st.args) >= 3
                ok2, g2 = fvalue(argtype(src, st.args[3]))
                ok2 || continue
                g = g2; args = st.args[4:end]
            elseif g === Core._apply_iterate && length(st.args) >= 3
                ok2, g2 = fvalue(argtype(src, st.args[3]))
                (ok2 && haskey(BMS, g2)) && (nsplat += 1)
                continue
            end
            haskey(BMS, g) || continue
            A = Any[CC.widenconst(argtype(src, a)) for a in args]
            rt = CC.widenconst(src.ssavaluetypes[i])
            if !all(isconcreteish, A)
                nnoncon[g] = get(nnoncon, g, 0) + 1
                push!(sites, Site(cname, string(Base.moduleroot(def.module)), ci.owner, g, A, :nonconcrete, loops[i], "-", "-", rt, Any, Any, :none, inb, :none, false, :none))
                continue
            end
            RA = Any[resolve_arg(a) for a in A]
            if any(r -> r[1] === :dynamic, RA)
                push!(sites, Site(cname, string(Base.moduleroot(def.module)), ci.owner, g, A, :dynamic_value, loops[i], "-", "-", rt, Any, Any, :none, inb, :none, false, :none))
                continue
            end
            tob = !any(r -> r[1] === :tobj, RA) ? :none : all(r -> r[1] !== :tobj || r[2] !== nothing, RA) ? :key : :nokey
            d = try decide(g, A, BMS[g], PMS[g]) catch e; Decision(:error, nothing, BM[]) end
            r_m0 = Any; r_b = Any; w = :none
            if d.case in (:guard_fallback, :guard_subtrait, :guard_methoderror)
                r_m0 = d.sel === nothing ? Union{} : d.sel isa PM ? m0_result(g, d.sel, A) : (d.sel.ret isa Type && d.sel.ret !== Any ? d.sel.ret : rt)
                r_b = reduce(CC.tmerge, Any[b.ret isa Type ? b.ret : Any for b in d.guards]; init = Union{})
                j = CC.tmerge(r_m0, r_b)
                w = j <: r_m0 ? :none : all(b -> b.ret !== Any, d.guards) ? :covered : :any   # `:declared_unresolved`: declared, parametric
                sf = all(b -> guard_sealed(b, A), d.guards)
                selret = d.sel === nothing ? nothing : d.sel isa BM ? d.sel.ret : declared_ret(d.sel.m)
                fk = d.sel === nothing ? :methoderror :
                     (d.sel isa BM && d.sel.origin === :default) || (selret !== Any && all(b -> b.ret == selret, d.guards)) ? :same_result :
                     :real_fallback
            else
                sf = false; fk = :none
            end
            push!(sites, Site(cname, string(Base.moduleroot(def.module)), ci.owner, g, A, d.case, loops[i], selname(d.sel),
                              join(unique(string(b.name, " [", laterpos(b, A), "]") for b in d.guards), "; "), rt, r_m0, r_b, w, inb, tob, sf, fk))
        end
    end
    # --- report ---
    isguard(s) = s.case in (:guard_fallback, :guard_subtrait, :guard_methoderror)
    hy(s) = s.f === Base.show && occursin("Hypothetical", s.guards)
    open(joinpath(out, "$label-sites.tsv"), "w") do io
        println(io, "function\targtypes\tcase\tin_loop\tin_bounded_code\ttrait_object\tsealed_fold\tfallback_kind\tselected_now\tguards_by\tr_today\tr_m0\tr_bounded\twiden\towner\tcaller_package\tcaller")
        for s in sites
            println(io, s.f, "\t", join(string.(s.A), ", "), "\t", s.case, "\t", s.inloop, "\t", s.inbounded, "\t", s.tobj, "\t", s.sealedfold, "\t", s.fbkind, "\t", s.sel, "\t", s.guards, "\t",
                    s.r_today, "\t", s.r_m0, "\t", s.r_b, "\t", s.widen, "\t", s.owner, "\t", s.callermod, "\t", s.caller)
        end
    end
    for (title, pick) in (("trait functions (the ports' bounded methods and defaults)", s -> s.f !== Base.show),
                          ("hypothetical Base.show(::IO, ::X) on an open set X (U5)", s -> s.f === Base.show))
        ss = filter(pick, sites)
        println("\n-- ", title)
        println("call sites: ", length(ss), " (concrete ", count(s -> s.case !== :nonconcrete, ss), ", non-concrete ", count(s -> s.case === :nonconcrete, ss), ")")
        for c in (:guard_fallback, :guard_subtrait, :guard_methoderror, :fold_positive, :plain, :methoderror_closed, :ambiguous_now, :ambiguous_later, :nonconcrete, :dynamic_value, :error)
            n = count(s -> s.case === c, ss)
            n == 0 && continue
            println("  ", rpad(c, 20), lpad(n, 6), "   in a loop ", lpad(count(s -> s.case === c && s.inloop, ss), 5),
                    "   in bounded code ", lpad(count(s -> s.case === c && s.inbounded, ss), 5))
        end
        gs = filter(isguard, ss)
        println("guards: ", length(gs), "; in a loop ", count(s -> s.inloop, gs), "; widening: none ", count(s -> s.widen === :none, gs),
                ", covered by a declared result ", count(s -> s.widen === :covered, gs), ", to Any ", count(s -> s.widen === :any, gs),
                "; in a loop and widening to Any ", count(s -> s.inloop && s.widen === :any, gs))
        println("guards with a trait object argument (in bounded code): ", count(s -> s.tobj !== :none, gs), " (its receiver type unknown: ", count(s -> s.tobj === :nokey, gs), ")")
        println("guards at the boundary (plain code calling trait code) ", count(s -> !s.inbounded, gs), ", inside bounded code ", count(s -> s.inbounded, gs))
        println("guards removed if sealed sets fold negatives: ", count(s -> s.sealedfold, gs), " of ", length(gs))
        println("what runs when the guard fails: MethodError ", count(s -> s.fbkind === :methoderror, gs), ", a default or the same declared result ",
                count(s -> s.fbkind === :same_result, gs), ", a real fallback ", count(s -> s.fbkind === :real_fallback, gs),
                " (in a loop: ", count(s -> s.fbkind === :real_fallback && s.inloop, gs), ")")
        for s in filter(s -> s.inbounded, gs)
            println("  in bounded code: [", s.case, "] ", s.f, "(", join(string.(s.A), ", "), ") in ", s.caller, "; later ", s.guards)
        end
        byf = Dict{String,Vector{Int}}()
        for s in gs
            v = get!(byf, string(s.f), [0, 0, 0])
            v[1] += 1; s.inloop && (v[2] += 1); s.widen === :any && (v[3] += 1)
        end
        println("guards per function (sites, in a loop, widening to Any):")
        for (k, v) in sort(collect(byf); by = x -> -x[2][1])[1:min(end, 25)]
            println("  ", rpad(k, 40), lpad(v[1], 5), lpad(v[2], 5), lpad(v[3], 5))
        end
        gl = filter(s -> s.inloop, gs)
        isempty(gl) || println("guards in a loop:")
        for s in gl[1:min(end, 40)]
            println("  [", s.case, "] ", s.f, "(", join(string.(s.A), ", "), ") in ", s.caller, "; now ", s.sel, "; later ", s.guards,
                    "; result ", s.r_m0, " ⊔ ", s.r_b, " (", s.widen, ")")
        end
    end
    println("\ncallers skipped: top-level thunks ", ntop, ", TraitWorld's machinery ", nmach, ", not re-inferable ", nfail,
            "; re-inferred ", nreinf, "; splatted calls ", nsplat)
    println("census time ", round(time() - t0; digits = 1), " s")
    return sites
end

# --- Base's abstract types as open sets (the other treatment) ---------------------------------------
"""
If Base's abstract types that BaseTraits' families range over (`AbstractArray`, `AbstractDict`,
`AbstractString`, and `Dates.Period`, `LinearAlgebra.Factorization` when loaded) and their abstract
subtypes admitted late members: the compiled specializations of every function at concrete argument
types whose selected method would lose to a method of the same function typed by such an abstract type
that the argument is not a subtype of. Counted from the method instances (specTypes) and their callers
(backedges), no re-inference.
"""
function base_families_open(label::String; out::String = joinpath(@__DIR__, "logs"))
    t0 = time()
    fams = Any[AbstractArray, AbstractDict, AbstractString]
    for (pk, nm) in ((:Dates, :Period), (:LinearAlgebra, :Factorization))
        for (k, m) in Base.loaded_modules
            k.name == String(pk) && isdefined(m, nm) && push!(fams, getglobal(m, nm))
        end
    end
    stdroot = normpath(Sys.STDLIB)
    juliamod(m::Module) = (r = Base.moduleroot(m); r === Core || r === Base ||
                           (p = pathof(r); p !== nothing && startswith(normpath(p), stdroot)))
    "Every type name in `T` (its parameters too) owned by Core, Base or a standard library: only Julia may declare it a member."
    function juliaowned(@nospecialize(T))
        T isa TypeVar && return juliaowned(T.ub)
        T isa Union && return juliaowned(T.a) && juliaowned(T.b)
        T isa UnionAll && return juliaowned(Base.unwrap_unionall(T))
        T isa DataType || return true
        juliamod(T.name.module) || return false
        return all(p -> !(p isa Type || p isa TypeVar) || juliaowned(p), T.parameters)
    end
    isopenfam(T) = T isa Type && T !== Union{} && isabstracttype(Base.unwrap_unionall(T)) && any(F -> T <: F, fams) && !(T isa Union)
    seenf = Base.IdSet{Any}()
    nmi = 0; ncall = 0; nfun = 0; nmi_pkg = 0; ncall_pkg = 0
    rows = Any[]
    for mod in allmods(), n in names(mod; all = true, imported = false)
        isdefined(mod, n) || continue
        f = try getglobal(mod, n) catch; continue end
        (f isa Function || f isa Type) || continue
        f in seenf && continue
        push!(seenf, f)
        ms = try collect(methods(f)) catch; continue end
        length(ms) < 2 && continue
        famms = Any[]
        for m in ms
            ps = Base.unwrap_unionall(m.sig).parameters
            for (i, p) in enumerate(ps)
                i == 1 && continue
                isopenfam(ubof(p)) && (push!(famms, (m, i)); break)
            end
        end
        isempty(famms) && continue
        hit = false
        for m0 in ms
            any(x -> x[1] === m0, famms) && continue
            for mi in Base.specializations(m0)
                mi isa Core.MethodInstance || continue
                A = mi.specTypes
                (A isa DataType && Base.isdispatchtuple(A)) || continue
                Ap = A.parameters
                found = nothing; latej = Int[]
                for (mf, _) in famms
                    pf = Base.unwrap_unionall(mf.sig).parameters
                    p0 = Base.unwrap_unionall(m0.sig).parameters
                    ok = true; better = false; worse = false
                    for i in 2:length(Ap)
                        P = ubof(i <= length(pf) ? pf[i] : (pf[end] isa Core.TypeofVararg ? pf[end] : (ok = false; break)))
                        Q = ubof(i <= length(p0) ? p0[i] : p0[end])
                        if isopenfam(P) && !(Ap[i] <: P)
                            corekind(Ap[i]) && (ok = false; break)
                            # a late member: the family's method beats m0 only where m0 is `Any` there (C7)
                            anyish(Q) ? (better = true) : (worse = true)
                            push!(latej, i)
                        elseif Ap[i] <: P
                            s1 = P <: Q; s2 = Q <: P
                            s1 && !s2 && (better = true); s2 && !s1 && (worse = true)
                        else
                            ok = false; break
                        end
                    end
                    ok && better && !worse && (found = mf; break)
                    empty!(latej)
                end
                found === nothing && continue
                hit = true
                nmi += 1
                nb = isdefined(mi, :backedges) ? count(e -> e isa Core.CodeInstance, mi.backedges) : 0
                ncall += nb
                # only Julia may declare a Julia-owned type a member of a Julia-owned family: such a negative stays folded
                pkg = any(j -> !juliaowned(Ap[j]), latej)
                pkg && (nmi_pkg += 1; ncall_pkg += nb)
                push!(rows, (f, A, m0, found, nb, pkg))
            end
        end
        hit && (nfun += 1)
    end
    open(joinpath(out, "$label-basefamilies.tsv"), "w") do io
        println(io, "function\tspecTypes\tselected_now\twould_lose_to\tstatic_callers\ta_package_could_declare")
        for (f, A, m0, mf, nb, pkg) in rows
            println(io, f, "\t", A, "\t", m0.module, ".", m0.name, sprint(show, m0.sig), "\t", mf.module, ".", mf.name, sprint(show, mf.sig), "\t", nb, "\t", pkg)
        end
    end
    println("\n-- Base's abstract types as open sets (", join(string.(fams), ", "), ")")
    println("functions ", nfun, "; specializations that would carry a guard ", nmi, "; their static callers (backedges) ", ncall)
    println("of them where a package (not only Julia) could declare the membership: specializations ", nmi_pkg, ", static callers ", ncall_pkg)
    byf = Dict{String,Vector{Int}}()
    for (f, A, m0, mf, nb, pkg) in rows
        v = get!(byf, string(f), [0, 0, 0, 0]); v[1] += 1; v[2] += nb; pkg && (v[3] += 1; v[4] += nb)
    end
    println("  function (specializations, static callers; where a package could declare: specializations, static callers)")
    for (k, v) in sort(collect(byf); by = x -> -x[2][4])[1:min(end, 20)]
        println("  ", rpad(k, 40), lpad(v[1], 6), lpad(v[2], 6), lpad(v[3], 6), lpad(v[4], 6))
    end
    println("time ", round(time() - t0; digits = 1), " s")
end

function run(label::String; kw...)
    out = get(ENV, "U9_OUT", joinpath(@__DIR__, "logs"))
    s = Base.invokelatest(census, label; out, kw...)
    get(ENV, "U9_BASEFAM", "1") == "1" && Base.invokelatest(base_families_open, label; out)
    return nothing
end

end # module
