# E-255 (U7): the counting Compiler, activated before a script runs; the counts written at exit.
# Loaded by run.jl, or by `julia -L prelude.jl` (e.g. Pkg.test(julia_args = `-L prelude.jl`)).
# U7_TAG names the logs: logs/<tag>-all.tsv, logs/<tag>-open.tsv, logs/<tag>-summary.txt.
pushfirst!(LOAD_PATH, joinpath(@__DIR__, "env"))
const Compiler = Base.require(Base.PkgId(Base.UUID("807dbc54-b67e-4c79-8afb-eafe4df6f2e1"), "Compiler"))
popfirst!(LOAD_PATH)
const U7 = @__DIR__
const TAG = ENV["U7_TAG"]
@assert pathof(Compiler) !== nothing && startswith(pathof(Compiler), U7) "not the counting Compiler: $(pathof(Compiler))"
# stdout stays clean: Pkg.test reads a probe's stdout (`show(Base.CacheFlags())`), and that probe runs this file too
redirect_stdout(devnull) do
    Compiler.activate!(; reflection = true, codegen = true)
end

fams = Tuple{Symbol,Symbol}[]
for l in eachline(joinpath(U7, "families.tsv"))
    p = split(l, '\t')
    t = (Symbol(p[1]), Symbol(p[2]))
    t in fams || push!(fams, t)
end

const KN = Dict(0x01 => "trait", 0x02 => "family", 0x04 => "Callable", 0x08 => "Dynamic", 0x20 => "Kept/Compiled")
kstr(k::UInt8) = k == 0 ? "-" : join([v for (b, v) in sort!(collect(KN)) if k & b != 0], "+") * (k & 0x10 != 0 ? " (in a Tuple)" : "")
short(x; n = 160) = (s = replace(sprint(show, x), '\t' => ' ', '\n' => ' '); length(s) > n ? first(s, n) * "…" : s)
function mistr(mi)
    mi isa Core.MethodInstance || return ("-", "-", "-")
    m = mi.def
    m isa Method || return (short(mi), string(m), "-")
    return (short(mi.specTypes; n = 200), string(m.module), string(m.file, ":", m.line))
end
siteclass(s::String) = startswith(s, "isa:") ? "isa_tfunc" : startswith(s, "subtype:") ? "subtype_tfunc" :
                       startswith(s, "tmeet:") ? "tmeet(Const)" : "typeintersect/hasintersect"

# who could declare a membership between the types of a fold (traits §10.1: the set's owner or the
# type's owner): the root modules of every type named in it. 0x01 Core/Base, 0x02 a standard library,
# 0x04 a package, 0x08 Main (a session's own code, where Lemma M of §11.4 says nothing)
function modcat(m::Module)
    r = Base.moduleroot(m)
    (r === Core || r === Base) && return 0x01
    r === Main && return 0x08
    p = pkgdir(r)
    return (p !== nothing && startswith(p, Sys.STDLIB)) ? 0x02 : 0x04
end
function owncat(@nospecialize(t), depth::Int = 0)
    depth > 4 && return 0x00
    t isa UnionAll && return owncat(Base.unwrap_unionall(t), depth)
    t isa Union && return owncat(t.a, depth) | owncat(t.b, depth)
    t isa Core.TypeofVararg && return isdefined(t, :T) ? owncat(t.T, depth) : 0x00
    t isa DataType || return 0x00
    k = modcat(t.name.module)
    for p in t.parameters
        k |= owncat(p, depth + 1)
    end
    return k
end
const OCN = (0x01 => "Core/Base", 0x02 => "stdlib", 0x04 => "package", 0x08 => "Main")
ocstr(k::UInt8) = join([v for (b, v) in OCN if k & b != 0], "+")
codecat(mi) = mi isa Core.MethodInstance && mi.def isa Method ? modcat(mi.def.module) : 0x00


# Does the negative answer rest on a membership (§13.4 (c), item 2: "rests on S ∉ X for an open X")?
# Yes when an open set X stands at the top of one side (or of a Union's member), or at the same position
# of two Tuples: then a late `S ∈ X` for a type S of the other side could make the intersection non-empty.
# No when the open set is only inside a Tuple and the other side is no Tuple (`Tuple{AbstractString, Int}`
# against `Module`): no membership changes that answer. Returns (X, S) or nothing.
# `mask`: 0x07 the open sets (traits, families, Callable); 0x20 `Kept`/`Compiled`, the proxy for `X`.
topopen(@nospecialize(t), mask::UInt8) = (t = Base.unwrap_unionall(t); t isa DataType && t.name !== Base.typename(Tuple) &&
                                          (Compiler._u7_kind(t) & mask) != 0)
function restpair(@nospecialize(a), @nospecialize(b), mask::UInt8)
    a = Base.unwrap_unionall(a); b = Base.unwrap_unionall(b)
    if a isa Union
        r = restpair(a.a, b, mask); r === nothing || return r
        return restpair(a.b, b, mask)
    elseif b isa Union
        r = restpair(a, b.a, mask); r === nothing || return r
        return restpair(a, b.b, mask)
    end
    topopen(a, mask) && return (a, b)
    topopen(b, mask) && return (b, a)
    if a isa DataType && b isa DataType && a.name === b.name === Base.typename(Tuple)
        pa = a.parameters; pb = b.parameters
        for i in 1:min(length(pa), length(pb))
            x = pa[i]; y = pb[i]
            x isa Core.TypeofVararg && (x = isdefined(x, :T) ? x.T : Any)
            y isa Core.TypeofVararg && (y = isdefined(y, :T) ? y.T : Any)
            r = restpair(x, y, mask); r === nothing || return r
        end
    end
    return nothing
end

# A fold that changes code (a branch or a statement dropped, a call or an assertion typed as throwing,
# a narrower type) against one that only feeds the compiler's bookkeeping (effects, whether an argument
# could be a Module, a Type, a Bool, a Symbol, a builtin; widening limits).
const BRANCH_SITES = Set(["tfuncs:381", "tfuncs:1320", "tfuncs:2047", "tfuncs:127", "abstractlattice:111",
    "typelattice:616", "typelattice:643", "abstractinterpretation:2012", "abstractinterpretation:2326",
    "abstractinterpretation:2352", "abstractinterpretation:2367", "abstractinterpretation:2910",
    "abstractinterpretation:3849", "passes:256", "passes:308", "passes:2206", "facts:760"])
sitecls(s::AbstractString) = (startswith(s, "isa:") || startswith(s, "subtype:") || startswith(s, "tmeet:") || s in BRANCH_SITES) ?
                             "branch" : "bookkeeping"
const PLUMBING = Any[Module, Type, TypeVar, Core.Builtin, Core.OpaqueClosure, Ptr,
                     GenericMemory, GenericMemoryRef, Method, Core.CodeInstance, Tuple{Any,Any}]
function othercls(@nospecialize(s))
    s = Base.unwrap_unionall(s)
    s isa DataType || return "other"
    for p in PLUMBING
        (s <: p || s === Base.unwrap_unionall(p)) && return "a compiler kind (Module, Type, builtin, memory)"
    end
    s.name === Base.typename(Type) && return "a compiler kind (Module, Type, builtin, memory)"
    r = Base.moduleroot(s.name.module)
    nameof(r) === :TraitWorld && return (s.name.name === :Dynamic ? "Dynamic" : "TraitWorld's machinery")
    return "a value's type"
end

const DONE = Ref(false)
function report()
    DONE[] && return
    DONE[] = true
    Compiler.u7_stop!()
    all = Compiler.U7_ALL; open_ = Compiler.U7_OPEN
    t0 = time()
    pct(a, b) = b == 0 ? "-" : string(round(100a / b; digits = 3), " %")
    # all negative folds, by site and kinds
    agg = Dict{Tuple{String,UInt8,UInt8,Symbol},Vector{Int}}()     # => [answers, statements]
    tot = 0; totst = length(all); totb = 0; totbst = 0; tfn = 0
    lit = 0; litst = 0
    for (k, c) in all
        (site, kL, kR, ctx, mi, pc) = k
        v = get!(() -> [0, 0], agg, (site, kL, kR, ctx))
        v[1] += c; v[2] += 1
        tot += c
        sitecls(site) == "branch" && (totb += c; totbst += 1)
        (startswith(site, "isa:") || startswith(site, "subtype:")) && (tfn += c)
        ((kL | kR) & 0x07) != 0 && (lit += c; litst += 1)
    end
    open(joinpath(U7, "logs", "$TAG-all.tsv"), "w") do io
        println(io, "site\tsite_class\tkind_lhs\tkind_rhs\tctx\tanswers\tstatements")
        for (k, v) in sort!(collect(agg); by = x -> -x[2][1])
            println(io, k[1], '\t', sitecls(k[1]), '\t', kstr(k[2]), '\t', kstr(k[3]), '\t', k[4], '\t', v[1], '\t', v[2])
        end
    end
    # the open records, classified
    tiers = Dict{String,Vector{Int}}()
    add!(key, c) = (v = get!(() -> [0, 0], tiers, key); v[1] += c; v[2] += 1)
    rows = Any[]
    for (k, c) in open_
        (site, kL, kR, ctx, mi, pc, inl, a, b) = k
        sc = sitecls(site)
        ck = codecat(mi)
        ccls = ck == 0x08 ? "Main code" : ck == 0x04 ? "package code" : ck == 0x00 ? "no code" : "Core/Base/stdlib code"
        loop = inl ? ", in a loop" : ""
        tier = "-"; X = nothing; S = nothing; oc = "-"
        rp = restpair(a, b, 0x07)
        if rp !== nothing
            tier = "T1"; X, S = rp; oc = othercls(S)
            add!("T1", c); add!("T1 $sc", c); add!("T1 $sc, compiling $ccls$loop", c); add!("T1 $sc, other side: $oc", c)
            tk = owncat(X) | owncat(S)
            if tk & 0x0c != 0
                tier = "T2"
                add!("T2", c); add!("T2 $sc", c); add!("T2 $sc, compiling $ccls$loop", c)
            end
            tk & 0x08 != 0 && (tier = "T3"; add!("T3", c); add!("T3 $sc", c))
        else
            rp = restpair(a, b, 0x20)
            if rp !== nothing
                tier = "P1"; X, S = rp; oc = othercls(S)
                add!("P1", c); add!("P1 $sc", c); add!("P1 $sc, other side: $oc", c)
                oc == "a value's type" && add!("P1 $sc, other side a value's type, compiling $ccls$loop", c)
            end
        end
        push!(rows, (c, site, sc, kL, kR, ctx, inl, pc, tier, X, S, oc, a, b, mi))
    end
    sort!(rows; by = r -> (r[9] == "-", -r[1]))
    open(joinpath(U7, "logs", "$TAG-open.tsv"), "w") do io
        println(io, "answers\tsite\tsite_class\tkind_lhs\tkind_rhs\tctx\tin_loop\tpc\ttier\topen_set\tother_side\tother_class\ttype_owners\tcode_owner\tmodule\tmethod_file\tspec\tlhs\trhs")
        for (c, site, sc, kL, kR, ctx, inl, pc, tier, X, S, oc, a, b, mi) in rows
            spec, mod, file = mistr(mi)
            println(io, c, '\t', site, '\t', sc, '\t', kstr(kL), '\t', kstr(kR), '\t', ctx, '\t', inl, '\t', pc, '\t', tier, '\t',
                    X === nothing ? "-" : short(X), '\t', S === nothing ? "-" : short(S), '\t', oc, '\t',
                    ocstr(owncat(a) | owncat(b)), '\t', ocstr(codecat(mi)), '\t', mod, '\t', file, '\t', spec, '\t', short(a), '\t', short(b))
        end
    end
    # summary
    s = IOBuffer()
    println(s, "E-255 (U7) $TAG: julia-1.13 $(readchomp(`git -C $(joinpath(U7, "../../../julia-1.13")) rev-parse --short HEAD`)), ",
            "TraitWorld $(readchomp(`git -C $(joinpath(U7, "../../../TraitWorld")) rev-parse --short HEAD`)), families: ", fams)
    println(s, "all negative folds: $tot answers at $totst statements (site, code, pc); branch sites: $totb answers at $totbst; isa/subtype tfuncs: $tfn answers")
    println(s, "an open set (trait, family, Callable) anywhere in the fold: $lit answers ($(pct(lit, tot))) at $litst statements")
    g(k) = get(tiers, k, [0, 0])
    for (t, what) in (("T1", "rests on a membership in an open set"),
                      ("T2", "T1, and a package or Main could still declare it (a package's or Main's type or set)"),
                      ("T3", "T1, with a Main type (Lemma M does not cover it)"),
                      ("P1", "proxy: rests on Kept{X}/Compiled{X}, which the unified model makes X (§5.2)"))
        v = g(t); vb = g("$t branch")
        println(s, "$t $what: $(v[1]) answers ($(pct(v[1], tot)) of all), $(v[2]) records; at branch sites $(vb[1]) ($(pct(vb[1], totb)) of branch-site answers), $(vb[2]) records")
    end
    println(s, "breakdown (answers, (statement, types) records):")
    for (k, v) in sort!(collect(tiers); by = first)
        println(s, "  ", k, ": ", v[1], ", ", v[2])
    end
    println(s, "top records at branch sites (T1, T2, T3, and P1 with a value's type on the other side):")
    n = 0
    for (c, site, sc, kL, kR, ctx, inl, pc, tier, X, S, oc, a, b, mi) in rows
        (tier == "-" || sc != "branch" || (tier == "P1" && oc != "a value's type")) && continue
        spec, mod, file = mistr(mi)
        println(s, "  $c × $tier $site in_loop=$inl $mod $file: ", short(a; n = 70), " vs ", short(b; n = 70))
        (n += 1) >= 15 && break
    end
    # families present now that the run did not know (declared in test files)
    tw = get(Base.loaded_modules, Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld"), nothing)
    if tw !== nothing
        extra = Set{Tuple{Symbol,Symbol}}()
        for f in (tw.implementation, tw.projection), m in methods(f)
            sig = Base.unwrap_unionall(m.sig)
            length(sig.parameters) >= 3 || continue
            R = sig.parameters[3]
            (R isa DataType && R.name === Base.typename(Type)) || continue
            v = R.parameters[1]
            v isa TypeVar || continue
            for u in Base.uniontypes(Base.unwrap_unionall(v.ub))
                u = Base.unwrap_unionall(u)
                (u isa DataType && isabstracttype(u) && !(u <: tw.Trait)) || continue
                t = (nameof(u.name.module), u.name.name)
                t in fams || push!(extra, t)
            end
        end
        println(s, "families declared during the run, not counted as open: ", isempty(extra) ? "none" : sort!(collect(extra)))
    end
    println(s, "report written in $(round(time() - t0; digits = 1)) s")
    txt = String(take!(s))
    write(joinpath(U7, "logs", "$TAG-summary.txt"), txt)
    print(stderr, txt)
end
atexit(report)

Compiler.u7_start!(fams)
