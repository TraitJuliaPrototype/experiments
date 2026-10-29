# E-253 (U5): the coherence rule's cost. A census over TraitWorld's registries in one session.
#
#     julia --project=<env> census.jl <label> <package> [<package> …]
#
# Loads the packages named (extension triggers among them), then reads:
# - memberships: the methods of `TraitWorld.conformance(::As{X}, u::T)` (one per implementation, family or
#   generic implementation), each classified by who declared it: the member's own package (`by_owner`; through a
#   type parameter it owns, `by_owner_param`), or not: a foreign type or family (`foreign_type`, `family_foreign`),
#   a generic implementation `A where {A <: S}` over a foreign `S` (`generic`) or the declarer's own `S`
#   (`generic_own_ub`), or a declaration in a package extension (`extension`);
# - bounded methods: the workers (a `TObj` or `CObj` argument) of every function a trait module has entries for
#   or gave workers to (`__tw_entries__`, `__tw_extended__`), each classified by the function's owner against
#   the defining module's owner (joint owners count), and whether the defining module is an extension;
# - for every bounded method on a foreign function (or defined in an extension) whose bound is a set with a
#   foreign member: whether a typed method of the function shields every foreign member (it covers the bounded
#   method's signature at the member and is typed, not `Any`, at the bounded position: types first).
# Prints a report and writes `<label>-hits.tsv`, `<label>-sets.tsv` beside this script (or in $U5_OUT).
using TraitWorld
const TW = TraitWorld

label = ARGS[1]
for p in ARGS[2:end]
    Core.eval(Main, :(using $(Symbol(p))))
end

const OUT = get(ENV, "U5_OUT", @__DIR__)
get(ENV, "U5_SELFTEST", "") == "1" && include(joinpath(@__DIR__, "selftest.jl"))

function allmods()
    seen = Base.IdSet{Module}()
    out = Module[]
    function walk(m::Module)
        m in seen && return
        push!(seen, m); push!(out, m)
        for n in names(m; all = true, imported = false)
            isdefined(m, n) || continue
            v = try getglobal(m, n) catch; continue end
            v isa Module && v !== m && parentmodule(v) === m && walk(v)
        end
    end
    for (_, m) in Base.loaded_modules
        walk(m)
    end
    return out
end

rootname(m::Module) = String(nameof(Base.moduleroot(m)))
ownername(o) = o isa Module ? String(nameof(o)) : string(o)
isext(m::Module) = TW._extension_parent(Base.moduleroot(m)) !== nothing
fam(X) = try TW._family(X) catch; X end
famname(F) = sprint(show, F)

# --- memberships ------------------------------------------------------------------------------------
struct Member
    F::Any            # the trait family it joins
    T::Any            # the member pattern (a type, a family `S{…} where …`, or a generic's upper bound)
    D::Module         # the declaring module
    kind::Symbol      # :by_owner, :by_owner_param, :foreign_type, :family_foreign, :generic, :generic_own_ub, :extension
    m::Method
end

function typenames(T)
    out = Core.TypeName[]
    T = Base.unwrap_unionall(T)
    if T isa Union
        append!(out, typenames(T.a)); append!(out, typenames(T.b))
    elseif T isa DataType
        push!(out, T.name)
    elseif T isa TypeVar
        append!(out, typenames(T.ub))
    end
    return out
end

function memberships()
    out = Member[]
    for m in methods(TW.conformance)
        sig = Base.unwrap_unionall(m.sig)
        ps = sig.parameters
        length(ps) == 3 || continue
        A = ps[2]
        A isa DataType && A.name === Base.typename(TW.As) || continue
        X = A.parameters[1]
        Tp = ps[3]
        Tp === Any && continue                                 # TraitWorld's fallback
        generic = Tp isa TypeVar
        T = generic ? Base.rewrap_unionall(Tp.ub, m.sig) : Base.rewrap_unionall(Tp, m.sig)
        D = m.module
        Do = TW.owner(D)
        tns = typenames(T)
        own = !generic && !isempty(tns) && all(tn -> TW.owns(Do, TW.owner(tn.module)), tns)
        # a generic implementation over the declarer's own abstract type (`A where {A <: S}`, S its own): its members
        # are S's subtypes, each declared `<: S` by its own owner in a package that depends on S's
        gown = generic && !isempty(tns) && all(tn -> TW.owns(Do, TW.owner(tn.module)), tns)
        # owned through a type parameter (`Vector{ColorName}`): every caller at the member names the declarer's type
        pown = !generic && !own && TW._owns(Do, T)
        kind = isext(D) ? :extension : generic ? (gown ? :generic_own_ub : :generic) : own ? :by_owner : pown ? :by_owner_param :
               T isa UnionAll ? :family_foreign : :foreign_type
        push!(out, Member(fam(X), T, D, kind, m))
    end
    return out
end

closure(F) = try Any[fam(Y) for Y in TW.trait_closure(F)] catch; Any[F] end
"Whether a member of family `Fm` is a member of the bound's family `Fb`: `Fb` is in `Fm`'s closure, or `Fb` is the wrapper standing for all of `Fm`'s input families."
function covers(Fb, Fm)
    for Y in closure(Fm)
        (Y == Fb || (Fb isa UnionAll && TW._wrapper(Y) == Fb)) && return true
    end
    return false
end
members_of(Fb, ms) = Member[x for x in ms if covers(Fb, x.F)]

# --- bounded methods --------------------------------------------------------------------------------
"The trait families a worker's argument is bounded by (minimal: no supertrait of another), `:callable`, or `nothing`."
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

fowner(f) = TW.owner(parentmodule(f))
isworkerlike(m::Method) = any(p -> bound_at(p) !== nothing, Base.unwrap_unionall(m.sig).parameters[2:end])
typed(m::Method) = !isworkerlike(m) && !TW._is_entry(m) && !TW._is_tagged(m) && !TW._is_tagged(m, 4)

"The parameter of signature `sig` at argument `i` (1 = the function), an upper bound for a type variable."
function param_at(sig, i)
    b = Base.unwrap_unionall(sig)
    t = try fieldtype(b, i) catch; return Any end
    t isa TypeVar && (t = t.ub)
    t isa Core.TypeofVararg && (t = t.T)
    return t
end

"The bounded method's signature with member pattern `T` at argument `i` (1 = the function), `Any` at other bounded arguments."
function bsig_at(m::Method, i::Int, T)
    b = Base.unwrap_unionall(m.sig)
    ps = Any[]
    for (j, p) in enumerate(b.parameters)
        if j == i
            push!(ps, T)
        elseif j > 1 && bound_at(p) !== nothing
            push!(ps, Base.unwrap_unionall(p) isa Core.TypeofVararg ? Vararg{Any} : Any)
        else
            push!(ps, p)
        end
    end
    return Base.rewrap_unionall(Tuple{ps...}, m.sig)
end

"A typed method of `f` that shields member `T` from the bounded method `m` at argument `i`, or `nothing`."
function shield(f, m::Method, i::Int, T)
    s = try bsig_at(m, i, T) catch; return nothing end
    cands = Method[]
    for c in methods(f)
        typed(c) || continue
        (try s <: c.sig catch; false end) || continue
        Any <: param_at(c.sig, i) && continue                 # untyped at the bounded argument: the bound beats it
        push!(cands, c)
    end
    isempty(cands) && return nothing
    best = cands[1]
    for c in cands[2:end]
        Base.morespecific(c.sig, best.sig) && (best = c)
    end
    return best
end

shortm(m::Method) = string(m.module, ".", m.name, " ", sprint(show, m.sig), " @ ", basename(string(m.file)), ":", m.line)

function census()
    mods = allmods()
    tmods = [m for m in mods if isdefined(m, :__trait_module__)]
    ms = memberships()
    fs = trait_functions(mods)
    println("== U5 census: ", label)
    println("julia ", VERSION, " ", Base.GIT_VERSION_INFO.commit_short, "; TraitWorld at ", pkgdir(TW))
    println("trait modules: ", length(tmods), " (", join(sort(unique(rootname.(tmods))), ", "), ")")
    println("memberships (conformance methods): ", length(ms))
    # --- sets: by owner or open, per package of the trait's definition ---
    traits = Any[]
    for m in mods, n in names(m; all = true, imported = false)
        isdefined(m, n) || continue
        v = try getglobal(m, n) catch; continue end
        (v isa Type && v !== Union{} && TW.is_trait(v)) || continue
        u = Base.unwrap_unionall(v)
        u isa DataType && u.name.module === m && u.name.wrapper === v || continue
        v in (TW.Trait, TW.InputTrait, TW.Subtrait, TW.InputSubtrait) && continue
        isabstracttype(u) || continue
        push!(traits, v)
    end
    # families with input parameters as declared by memberships
    allF = unique(Any[traits..., (x.F for x in ms)...])
    open(joinpath(OUT, "$label-members.tsv"), "w") do io
        println(io, "set\tmember\tkind\tdeclared_in")
        for x in ms
            println(io, famname(x.F), "\t", x.T, "\t", x.kind, "\t", x.D)
        end
    end
    open(joinpath(OUT, "$label-sets.tsv"), "w") do io
        println(io, "package\tmodule\tset\tmode\tmode_refined\tmembers\tby_owner\tforeign\tforeign_kinds\tforeign_by")
        for F in allF
            mm = members_of(F, ms)
            fr = [x for x in mm if !(x.kind in (:by_owner, :by_owner_param))]
            mode = isempty(mm) ? "no_members" : isempty(fr) ? "members_by_owner" : "open"
            mode2 = isempty(mm) ? "no_members" : all(x -> x.kind in (:by_owner, :by_owner_param, :generic_own_ub), mm) ? "members_by_owner" : "open"
            kinds = join(sort(unique(string.(getfield.(fr, :kind)))), ",")
            by = join(sort(unique(rootname.(getfield.(fr, :D)) .* "")), ",")
            println(io, rootname(Base.unwrap_unionall(F).name.module), "\t", Base.unwrap_unionall(F).name.module, "\t", famname(F), "\t", mode, "\t", mode2, "\t", length(mm), "\t",
                    length(mm) - length(fr), "\t", length(fr), "\t", kinds, "\t", by)
        end
    end
    # --- bounded methods ---
    nb = Dict{String,Vector{Int}}()     # package => [bounded, on foreign fn or in ext, of those with a foreign-member set, unshielded]
    hits = Any[]
    bio = open(joinpath(OUT, "$label-bounded.tsv"), "w")
    println(bio, "package\tdefining_module\tfunction\tfunction_owner\tforeign_fn\tin_extension\tbounds\tmethod")
    for f in fs
        for m in methods(f)
            ps = Base.unwrap_unionall(m.sig).parameters
            bpos = [(i, bound_at(ps[i])) for i in 2:length(ps) if bound_at(ps[i]) !== nothing]
            isempty(bpos) && continue
            D = m.module
            pk = rootname(D)
            c = get!(nb, pk, [0, 0, 0, 0, 0])
            c[1] += 1
            Do = TW.owner(D)
            fo = fowner(f)
            foreignf = !TW.owns(Do, fo)
            inext = isext(D)
            println(bio, pk, "\t", D, "\t", f, "\t", ownername(fo), "\t", foreignf, "\t", inext, "\t",
                    join([string(i - 1, ":", B === :callable ? "Callable" : join(famname.(B), "+")) for (i, B) in bpos], " "), "\t", shortm(m))
            (foreignf || inext) || continue
            c[2] += 1
            # an argument type of the defining package's own in the signature (not a bound): every caller names it
            ownarg = any(i -> !any(b -> b[1] == i, bpos) && any(o -> TW.owns(Do, o), TW.sig_owners(ps[i])), 2:length(ps))
            for (i, B) in bpos
                if B === :callable
                    push!(hits, (pk, f, m, i, "Callable", "callable", Member[], ownarg, foreignf, inext))
                    continue
                end
                for F in B
                    fr = [x for x in members_of(F, ms) if !(x.kind in (:by_owner, :by_owner_param))]
                    isempty(fr) && continue
                    push!(hits, (pk, f, m, i, famname(F), "set", fr, ownarg, foreignf, inext))
                end
            end
        end
    end
    close(bio)
    open(joinpath(OUT, "$label-hits.tsv"), "w") do io
        println(io, "package\tfunction\tfunction_owner\tposition\tset\tforeign_fn\tin_extension\town_arg_type\tmembers_foreign\tunshielded\tshields\tmethod")
        seen = Set{Any}()
        for (pk, f, m, i, Fn, kind, fr, ownarg, foreignf, inext) in hits
            if kind == "callable"
                println(io, pk, "\t", f, "\t", ownername(fowner(f)), "\t", i - 1, "\tCallable\t", foreignf, "\t", inext, "\t", ownarg, "\t0\t-\t-\t", shortm(m))
                continue
            end
            uns = String[]; shs = String[]
            for x in fr
                s = shield(f, m, i, x.T)
                if s === nothing
                    push!(uns, string(x.T, " [", x.kind, " by ", rootname(x.D), "]"))
                else
                    push!(shs, string(x.T, " => ", s.module, ".", s.name, sprint(show, s.sig)))
                end
            end
            if (m, i) ∉ seen
                push!(seen, (m, i))
                c = nb[pk]; c[3] += 1; isempty(uns) || (c[4] += 1)
            end
            println(io, pk, "\t", f, "\t", ownername(fowner(f)), "\t", i - 1, "\t", Fn, "\t", foreignf, "\t", inext, "\t", ownarg, "\t",
                    length(fr), "\t", isempty(uns) ? "-" : join(uns, "; "), "\t", isempty(shs) ? "-" : join(shs, "; "), "\t", shortm(m))
        end
    end
    println("\nbounded methods per package: bounded / on a foreign function or in an extension / those bounded by a set with a foreign member (method×position) / with an unshielded member")
    for k in sort(collect(keys(nb)))
        c = nb[k]
        println("  ", rpad(k, 34), lpad(c[1], 5), lpad(c[2], 5), lpad(c[3], 5), lpad(c[4], 5))
    end
    println("\nmemberships by kind and declaring package:")
    for k in sort(unique([(rootname(x.D), x.kind) for x in ms]))
        println("  ", rpad(k[1], 34), rpad(string(k[2]), 16), count(x -> (rootname(x.D), x.kind) == k, ms))
    end
    println("\nhits (also in $label-hits.tsv):")
    for (pk, f, m, i, Fn, kind, fr, ownarg, foreignf, inext) in hits
        println("  [", pk, "] ", f, " arg ", i - 1, " bound ", Fn, kind == "callable" ? " (Callable: no declared membership)" : " ($(length(fr)) foreign members)",
                foreignf ? "" : " [own function, in an extension]", ownarg ? " [own argument type in the signature]" : "")
        println("      ", shortm(m))
    end
end
"""
The known wish, hypothetically: a bounded `Base.show(io::IO, x::X)` for every open set `X` (none exists in the code
bases). For each foreign member, Base's typed `show` method that would shield it, if any.
"""
function hypo_show()
    ms = memberships()
    Fs = unique(Any[x.F for x in ms])
    open(joinpath(OUT, "$label-hypo-show.tsv"), "w") do io
        println(io, "set\tforeign_members\tshielded\tunshielded_members")
        for F in Fs
            fr = [x for x in members_of(F, ms) if !(x.kind in (:by_owner, :by_owner_param))]
            isempty(fr) && continue
            uns = String[]
            for x in fr
                s = try Base.rewrap_unionall(Tuple{typeof(show),IO,Base.unwrap_unionall(x.T)}, x.T) catch; Tuple{typeof(show),IO,x.T} end
                ok = any(c -> typed(c) && (try s <: c.sig catch; false end) && !(Any <: param_at(c.sig, 3)), methods(show))
                ok || push!(uns, string(x.T))
            end
            println(io, famname(F), "\t", length(fr), "\t", length(fr) - length(uns), "\t", join(uns, "; "))
        end
    end
end
Base.invokelatest(census)
Base.invokelatest(hypo_show)
