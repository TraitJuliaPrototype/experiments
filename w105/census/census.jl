# E-263 and E-264 (W-105): two censuses of the ports under the draft reference's rules.
#
# E-263, keys: every membership TraitWorld records in the session's ports (`implementation`'s and `projection`'s
#   methods), each concrete member's key by TraitWorld's own key function (`_key_and_slots`: the receiver, the
#   member itself where it serves an operation by its own methods, its forwarding field's type where it forwards,
#   `Nothing` where defaults serve every operation; and the declared fields' types). This is the draft's key
#   (traits §7.2). Families are classified by their declaration (a forwarding family or not).
# E-264, `@open`: every method with a trait position in the ports' modules (TraitWorld's workers), inferred at
#   archetypes. TraitWorld's definition checker (`worker_problems`) reports what its own rule refuses; the ports
#   pass it, so the census adds what the draft's rule (traits §7.3) calls open and TraitWorld's admits: a value
#   whose type is built from the argument's type (a struct parameter set from it, `typeof(keep(x))` where the
#   draft's `keep(x)` is `x`, a closure capturing it, a `Ref` of it). Methods whose trait parameters are left
#   open are checked at archetypes with the open parameters as `ParamOpen` (E-258's construction).
#
# Run: run.sh <session> (sets the load path and the packages). Output: logs/<session>-keys.tsv,
# logs/<session>-methods.tsv, and the summary on stdout.

const T0 = time()
using TraitWorld
using TraitWorld.BaseTraits
const TW = TraitWorld
const CC = TW._CC
const SESSION = ARGS[1]
const PKGS = Symbol.(split(ENV["CENSUS_PKGS"], ","))
const SCOPE = Symbol.(split(ENV["CENSUS_SCOPE"], ","))           # the package roots counted in this session
for p in PKGS
    Core.eval(Main, :(import $p))
end
const ROOTS = Module[getfield(Main, p) for p in SCOPE if p !== :BaseTraits]
const WITH_BT = :BaseTraits in SCOPE
println("# session ", SESSION, ": loaded ", join(PKGS, ", "), " in ", round(time() - T0; digits = 1), " s; counted: ", join(SCOPE, ", "))

isbt(m::Module) = m === TW.BaseTraits || (parentmodule(m) !== m && isbt(parentmodule(m)))
inscope(m::Module) = (WITH_BT && isbt(m)) || Base.moduleroot(m) in ROOTS
port(m::Module) = isbt(m) ? "BaseTraits" : string(nameof(Base.moduleroot(m)))
loc(m::Method) = string(basename(string(m.file)), ":", m.line)

# ------------------------------------------------------------------------------------------------ E-263
function trait_and_member(m::Method)
    sig = Base.unwrap_unionall(m.sig)
    ps = sig.parameters
    length(ps) == 3 || return nothing
    a, b = ps[2], ps[3]
    (a isa DataType && a <: Type && b isa DataType && b <: Type) || return nothing
    return (a.parameters[1], b.parameters[1], m.sig isa UnionAll)
end

"The type name a member pattern names: through a type variable to its bound."
function rname(@nospecialize(R))
    for _ in 1:4
        R = Base.unwrap_unionall(R)
        R isa TypeVar ? (R = R.ub) : break
    end
    R isa DataType && return R.name
    return string(R)
end

function keys_census(io)
    recs = Dict{Any,Any}()                      # (X, R) => (module, family, from)
    for (f, tag) in ((TW.implementation, "implementation"), (TW.projection, "projection"))
        for m in methods(f)
            inscope(m.module) || continue
            t = trait_and_member(m)
            t === nothing && continue
            X, R, fam = t
            k = (X, R)
            haskey(recs, k) ? (recs[k] = (recs[k][1], recs[k][2], recs[k][3] * "+" * tag)) : (recs[k] = (m.module, fam, tag))
        end
    end
    fwdfam = Set{Any}()                          # families that forward: a projection method with a pattern
    for m in methods(TW.projection)
        t = trait_and_member(m)
        t === nothing && continue
        t[3] && push!(fwdfam, (TW._family(Base.unwrap_unionall(t[1])), rname(t[2])))
    end
    rows = Any[]
    for ((X, R), (mod, fam, tag)) in recs
        kind = "?"; key = ""
        Xf = TW._family(Base.unwrap_unionall(X))
        if fam
            Rn = rname(R)
            # a family's projection record is for its declared fields (a mapping) or a forwarding field; no family in
            # the ports forwards (`by` appears only in TraitMakie's four concrete `Live` memberships: README)
            kind = isempty(Base.invokelatest(TW._ops, Xf)) ? "family-none" : (Xf, Rn) in fwdfam ? "family-own, fields mapped" : "family-own"
        else
            try
                p = Base.invokelatest(TW.proj_lookup, X, R)
                if p === nothing
                    kind = "no-projection"
                else
                    w = Base.invokelatest(TW.proj_witness, X, R, p)
                    K, _ = Base.invokelatest(TW._key_and_slots, X, p, R, w)
                    rcv = K isa DataType && K.name === Base.typename(TW.Key) ? K.parameters[1] : K
                    kind = rcv === Nothing ? "none" : rcv == R ? "own" : "forwards"
                    key = string(K)
                end
            catch e
                kind = "error"; key = first(sprint(showerror, e), 160)
            end
        end
        push!(rows, (port(mod), string(Xf), string(R), fam ? "family" : "concrete", kind, key, tag))
    end
    sort!(rows)
    println(io, "port\ttrait\tmember\tform\tkind\tkey\tdeclared by")
    for r in rows
        println(io, join(r, "\t"))
    end
    return rows
end

# ------------------------------------------------------------------------------------------------ E-264
# E-258's construction of an archetype with open parameters (`ParamOpen`), MutableIndexable's supertrait parameter
# tied to its own.
const MI = TW.BaseTraits.MutableIndexable
const IX = TW.BaseTraits.Indexable
function tied_patterns(@nospecialize(lb))
    ps = Any[Base.uniontypes(lb)...]
    p1(u) = Base.unwrap_unionall(u).parameters[1]
    mi = findfirst(u -> TW._family(u) === TW._family(MI) && !(p1(u) isa TypeVar), ps)
    mi === nothing && return ps
    T = p1(ps[mi])
    return Any[(TW._family(u) === TW._family(IX) && p1(u) isa TypeVar) ? IX{T} : u for u in ps]
end
function tied_archetype_tobj(pats)
    views = Any[]
    for Yp in pats
        X = TW._family(Yp)
        u = Base.unwrap_unionall(Yp)
        fixed = u isa DataType && length(u.parameters) > 1 ?
                Any[p isa TypeVar ? TW.ParamOpen : p for p in u.parameters[1:end-1]] : Any[]
        A = TW.Archetype{X,Tuple{fixed...}}
        for Y in TW._arch_traits(X)
            push!(views, TW.View{TW._instance(Y, A),TW.ArchWit,A,length(TW.trait_fields(Y)),Nothing})
        end
    end
    return TW.TObj{TW._encode_traits(Any[v.parameters[1] for v in views]),Tuple{views...}}
end
"The archetype signature: (status, signature or nothing)."
function arch_sig(m::Method)
    sig = Base.unwrap_unionall(m.sig)
    sig isa DataType || return ("no-signature", nothing)
    ps = sig.parameters
    (isempty(ps) || ps[1] === typeof(Core.kwcall)) && return ("keywords", nothing)
    out = Any[ps[1]]; bounded = false; openp = false
    for k in 2:length(ps)
        p = ps[k]
        Base.isvarargtype(p) && return ("vararg", nothing)
        lb = TW._tobj_lb(p)
        if lb === nothing || lb === Union{}
            q = p isa TypeVar ? p.ub : p
            TW._hascallable(q) && return ("callable", nothing)
            push!(out, q)
        else
            TW._open_params(lb) && (openp = true)
            push!(out, tied_archetype_tobj(tied_patterns(lb)))
            bounded = true
        end
    end
    bounded || return ("no-trait-position", nothing)
    return (openp ? "open-parameters" : "checked", Tuple{out...})
end

const ARCH = (Base.typename(TW.TObj), Base.typename(TW.Archetype), Base.typename(TW.View))
"Whether type `T` is built from an archetype (the argument's type) outside TraitWorld's machinery."
function mentions_arch(@nospecialize(T), depth = 0)
    depth > 8 && return false
    T isa TypeVar && return mentions_arch(T.ub, depth + 1)
    T isa UnionAll && return mentions_arch(Base.unwrap_unionall(T), depth + 1)
    T isa Union && return mentions_arch(T.a, depth + 1) || mentions_arch(T.b, depth + 1)
    T isa DataType || return false
    T.name in ARCH && return true
    T.name === Base.typename(TW.Kept) && return false          # `Kept{X}`: a slot typed by the trait (the draft's `X`)
    return any(p -> mentions_arch(p, depth + 1), T.parameters)
end
machinery(@nospecialize(T)) = (m = parentmodule(T); Base.moduleroot(m) === TW && !isbt(m))
"What the draft's rule calls open and TraitWorld's admits: values whose type is built from the argument's type."
function draft_flags(@nospecialize(asig))
    flags = String[]
    for (src, _) in Base.code_typed_by_type(asig; optimize = false)
        sp = src.parent isa Core.MethodInstance ? CC.sptypes_from_meth_instance(src.parent) : CC.EMPTY_SPTYPES
        # `typeof` of a kept value: TraitWorld's `keep(x)` is a `Kept`, the draft's is `x` itself where compiled per key
        for ex in src.code
            ex isa Expr && ex.head === :(=) && (ex = ex.args[2])
            ex isa Expr && ex.head === :call && length(ex.args) == 2 || continue
            fT = CC.argextype(ex.args[1], src, sp)
            (fT isa CC.Const && fT.val === typeof) || continue
            A = CC.widenconst(CC.argextype(ex.args[2], src, sp))
            A isa DataType && A.name === Base.typename(TW.Kept) && push!(flags, "typeof(keep(t))")
        end
        for t in src.ssavaluetypes
            T = CC.widenconst(t)
            T isa DataType || continue
            (T <: Tuple || T <: Type || machinery(T)) && continue
            (T.name in ARCH || T.name === Base.typename(TW.Kept)) && continue
            mentions_arch(T) || continue
            n = string(T.name.name)
            push!(flags, startswith(n, "#") ? "a closure capturing it" : "a $(n){…} built from its type")
        end
    end
    return unique(flags)
end

"Public: the function's (or constructor's type's) name exported or public in its own module."
function ispublic(m::Method)
    ft = Base.unwrap_unionall(m.sig).parameters[1]
    try
        if ft isa DataType && ft <: Type
            T = Base.unwrap_unionall(ft.parameters[1])
            T isa TypeVar && (T = Base.unwrap_unionall(T.ub))
            mod, name = parentmodule(T), nameof(T)
        else
            f = ft.instance
            mod, name = parentmodule(f), nameof(f)
        end
        return Base.isexported(mod, name) || Base.ispublic(mod, name)
    catch
        return false
    end
end
fname(m::Method) = (ft = Base.unwrap_unionall(m.sig).parameters[1]; ft isa DataType && ft <: Type ? string("(constructor) ", ft) : string(m.name))

const NOPS = Ref(0)
const NMACH = Ref(0)
function methods_census(io)
    ms = Method[]
    Base.visit(Core.methodtable) do m
        m isa Method || return
        inscope(m.module) || return
        sig = Base.unwrap_unionall(m.sig)
        sig isa DataType || return
        any(p -> TW._tobj_lb(p) !== nothing, sig.parameters) || return
        ft = sig.parameters[1]
        isop = ft isa DataType && isdefined(ft, :instance) && Base.invokelatest(TW.is_operation_function, ft.instance)
        # TraitWorld's machinery generated into a user's module (`_tgetprop`, `_tsetprop!`: declared fields)
        ismach = ft isa DataType && isdefined(ft, :instance) && machinery(typeof(ft.instance)) && !isbt(parentmodule(ft.instance))
        isop ? (NOPS[] += 1) : ismach ? (NMACH[] += 1) : push!(ms, m)
    end
    rows = Any[]
    for m in ms
        st, asig = arch_sig(m)
        probs = String[]; flags = String[]
        if asig !== nothing
            try
                append!(probs, Base.invokelatest(TW.worker_problems, asig)::Vector{String})
                append!(flags, Base.invokelatest(draft_flags, asig))
            catch e
                st = "error"; push!(probs, "checker failed: " * first(sprint(showerror, e), 160))
            end
        end
        cls = asig === nothing || st == "error" ? "unchecked" : (isempty(flags) && isempty(probs) ? "bounded" : "open")
        push!(rows, (port(m.module), string(m.module), fname(m), loc(m), ispublic(m) ? "public" : "internal", st, cls,
                     join(flags, "; "), join(map(p -> first(replace(p, '\n' => ' '), 200), probs), " | ")))
    end
    sort!(rows)
    println(io, "port\tmodule\tfunction\tlocation\tvisibility\tcheck\tclass\tdraft: open by\tTraitWorld's checker")
    for r in rows
        println(io, join(r, "\t"))
    end
    return rows
end

# ------------------------------------------------------------------------------------------------ run
mkpath(joinpath(@__DIR__, "logs"))
krows = open(io -> keys_census(io), joinpath(@__DIR__, "logs", "$SESSION-keys.tsv"), "w")
mrows = open(io -> methods_census(io), joinpath(@__DIR__, "logs", "$SESSION-methods.tsv"), "w")

println("\n## E-263: memberships and keys")
for p in sort(unique(r[1] for r in krows))
    rs = filter(r -> r[1] == p, krows)
    conc = filter(r -> r[4] == "concrete", rs)
    fam = filter(r -> r[4] == "family", rs)
    kinds(v) = join(["$k $(count(r -> r[5] == k, v))" for k in sort(unique(r[5] for r in v))], ", ")
    groups = Dict{Tuple{String,String},Int}()
    for r in conc
        r[6] == "" && continue
        groups[(r[2], r[6])] = get(groups, (r[2], r[6]), 0) + 1
    end
    shared = filter(kv -> kv[2] >= 2, groups)
    println(p, ": ", length(rs), " memberships; concrete ", length(conc), " (", kinds(conc), "); families ", length(fam),
            " (", kinds(fam), "); distinct keys among concrete ", length(groups), ", keys with two members or more ",
            length(shared), " (", sum(values(shared); init = 0), " members)")
end

println("\n## E-264: methods at traits")
for p in sort(unique(r[1] for r in mrows))
    rs = filter(r -> r[1] == p, mrows)
    c(v, k) = count(r -> r[7] == k, v)
    pub = filter(r -> r[5] == "public", rs); int = filter(r -> r[5] == "internal", rs)
    println(p, ": ", length(rs), " methods; public ", length(pub), " (bounded ", c(pub, "bounded"), ", open ", c(pub, "open"),
            ", unchecked ", c(pub, "unchecked"), "); internal ", length(int), " (bounded ", c(int, "bounded"), ", open ",
            c(int, "open"), ", unchecked ", c(int, "unchecked"), ")")
end
println("\noperations' own methods (the trait's method per operation), not counted: ", NOPS[])
println("TraitWorld's machinery in users' modules, not counted: ", NMACH[])
println("checked with open trait parameters: ", count(r -> r[6] == "open-parameters", mrows))
println("unchecked by reason: ", join(["$k $(count(r -> r[6] == k, mrows))" for k in sort(unique(r[6] for r in mrows)) if !(k in ("checked", "open-parameters"))], ", "))
println("done in ", round(time() - T0; digits = 1), " s")
