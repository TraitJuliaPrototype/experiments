# U1 (E-258): how much generic code is fully bounded as written?
#
# Each sample function (samples/*.jl) is evaluated into a scratch trait module with its argument
# annotations replaced by a bound, then checked by TraitWorld's definition checker at archetypes
# (`archetype_sig` + `worker_problems`, what `definition_problems` and `check_definitions` run at a
# trait module's end). A function is fully bounded if every bounded method is checked at archetypes
# with no problem, open if the checker reports a problem; each problem names what the body reaches
# outside the contract.
#
# Two variants of the bounds:
#   A: the existing traits only: BaseTraits' (Indexable, Iterable, HasLength, MutableIndexable,
#      Resizable) for Base's sample, the port's trait for the ports' samples (Column, TableSource;
#      Positions, Sample, ColorSpec; GraphInterface, VertexDynamics, EdgeDynamics).
#   B: A plus the abstract type's documented interface as a contract (U1Contracts below): for an
#      AbstractVector, BaseTraits' traits and ArrayOps (size, axes, firstindex, lastindex, eachindex,
#      IndexStyle, similar); for an AbstractGraph, GraphOps (vertices, edges, outneighbors, inneighbors,
#      has_vertex, edgetype). This is the reading of the exploration's level 3: the abstract type is
#      the set, its documented interface the contract.
#
# Run: run.sh (sets the load path; through experiments/tools/jl). Output: logs/results-<variant>.tsv
# and the log on stdout.

const HERE = @__DIR__
t0 = time()
using TraitWorld
using TraitWorld.BaseTraits
import Tables, DataFrames, Statistics
import TraitMakie, MakieCompat
import Graphs
const TW = TraitWorld
println("loaded in ", round(time() - t0; digits = 1), " s")

# --- the documented interfaces as contracts (variant B) ----------------------------------------------
@trait_module module U1Contracts
using TraitWorld
using Graphs: Graphs
export ArrayOps, GraphOps
"Base's AbstractArray interface (the manual's Interfaces chapter) beyond BaseTraits' traits, for vectors."
@trait ArrayOps{T} begin
    T = eltype(Self)
    Base.size(c::ArrayOps)::Tuple{Int}
    Base.axes(c::ArrayOps)::Tuple{Base.OneTo{Int}}
    Base.firstindex(c::ArrayOps)::Int
    Base.lastindex(c::ArrayOps)::Int
    Base.eachindex(c::ArrayOps)::Base.OneTo{Int}
    Base.IndexStyle(c::ArrayOps)::IndexStyle
    Base.similar(c::ArrayOps{T})::Vector{T}
    Base.similar(c::ArrayOps, S::Type)::AbstractVector
    Base.similar(c::ArrayOps, S::Type, n::Int)::AbstractVector
end
"Graphs' AbstractGraph interface (its documented required methods) beyond GraphInterface."
@trait GraphOps{V <: Integer} begin
    V = eltype(Self)
    Graphs.vertices(g::GraphOps{V})::AbstractVector{V}
    Graphs.edges(g::GraphOps)::Any
    Graphs.outneighbors(g::GraphOps{V}, v::V)::AbstractVector{V}
    Graphs.inneighbors(g::GraphOps{V}, v::V)::AbstractVector{V}
    Graphs.has_vertex(g::GraphOps{V}, v::V)::Bool
    Graphs.edgetype(g::GraphOps)::Type
end
end

# --- NetworkDynamics' helpers the samples call that take no graph and no dynamics: stubs -------------
module NDStubs
using Graphs: Graphs
export FeedForwardType, PureFeedForward, FeedForward, NoFeedForward, PureStateMap, out_range, state_range,
       in_range, parameter_range, extbuf_range, get_src_dst, hasff, is_loopback, unique_mappings, IMStub,
       _evalf, _evalg
abstract type FeedForwardType end
struct PureFeedForward <: FeedForwardType end
struct FeedForward <: FeedForwardType end
struct NoFeedForward <: FeedForwardType end
struct PureStateMap <: FeedForwardType end
for f in (:out_range, :state_range, :in_range, :parameter_range, :extbuf_range)
    @eval $f(batch, i, args...) = Base.inferencebarrier(1:1)::UnitRange{Int}
end
get_src_dst(gbuf, batch, i) = Base.inferencebarrier(nothing)
hasff(m) = Base.inferencebarrier(false)::Bool
is_loopback(m) = Base.inferencebarrier(false)::Bool
unique_mappings(names, r) = Base.inferencebarrier(nothing)
struct IMStub{G}
    g::G
    edgevec::Vector{Graphs.SimpleEdge{Int}}
    v_states::Vector{UnitRange{Int}}
    e_states::Vector{UnitRange{Int}}
    unique_vnames::Any
    unique_enames::Any
end
# coreloop.jl
_evalf(::Val{:f}, hf::Bool) = hf
_evalf(::Val{:g}, hf::Bool) = false
_evalf(::Val{:fg}, hf::Bool) = hf
_evalg(::Val{:f}) = false
_evalg(::Val{:g}) = true
_evalg(::Val{:fg}) = true
end

# --- NetworkDynamics' component traits, as declared on the ports (component_dynamics.jl) --------------
@trait_module module U1NDTraits
using TraitWorld
using ..NDStubs: FeedForwardType
export ComponentDynamics, VertexDynamics, EdgeDynamics, hasf, fftype, pdim, extdim, vertexf!, vertexg!, edgef!, edgeg!
@trait ComponentDynamics begin
    @default_with_dynamic_self
    hasf(m::ComponentDynamics)::Bool
    fftype(m::ComponentDynamics)::FeedForwardType
    pdim(m::ComponentDynamics)::Int
    extdim(m::ComponentDynamics)::Int = 0
end
@trait VertexDynamics <: ComponentDynamics begin
    @default_with_dynamic_self
    vertexf!(m::VertexDynamics, du, u, ins, p, t)::Nothing
    vertexg!(m::VertexDynamics, out, u, ins, p, t)::Nothing
end
@trait EdgeDynamics <: ComponentDynamics begin
    @default_with_dynamic_self
    edgef!(m::EdgeDynamics, du, u, ins, p, t)::Nothing
    edgeg!(m::EdgeDynamics, osrc, odst, u, ins, p, t)::Nothing
end
end

# --- the bounds per variant ----------------------------------------------------------------------------
vec(T) = "(Indexable{$T}, Iterable{$T})"
mvec(T) = "(MutableIndexable{$T}, Iterable{$T})"
const VARIANTS = Dict(
    "A" => Dict(
        "__IDX__" => vec("Float64"), "__MIDX__" => mvec("Float64"),
        "__RES__" => "(MutableIndexable{Float64}, Iterable{Float64}, Resizable)",
        "__BIDX__" => vec("Bool"), "__ITER__" => "Iterable{Float64}",
        "__COL__" => "Column{Float64}", "__COLB__" => "Column{Bool}", "__COLANY__" => "Column{Any}",
        "__MCOL__" => "Column{Float64}", "__TAB__" => "TableSource",
        "__SAMPLE__" => "Sample", "__POS__" => "Positions", "__COLOR__" => "ColorSpec",
        "__GRAPH__" => "GraphInterface{Int}", "__VDYN__" => "VertexDynamics", "__EDYN__" => "EdgeDynamics"),
    "B" => Dict(
        "__IDX__" => "(Indexable{Float64}, Iterable{Float64}, ArrayOps{Float64})",
        "__MIDX__" => "(MutableIndexable{Float64}, Iterable{Float64}, ArrayOps{Float64})",
        "__RES__" => "(MutableIndexable{Float64}, Iterable{Float64}, Resizable, ArrayOps{Float64})",
        "__BIDX__" => "(Indexable{Bool}, Iterable{Bool}, ArrayOps{Bool})", "__ITER__" => "Iterable{Float64}",
        "__COL__" => "(Column{Float64}, Indexable{Float64}, Iterable{Float64}, ArrayOps{Float64})",
        "__COLB__" => "(Column{Bool}, Indexable{Bool}, Iterable{Bool}, ArrayOps{Bool})",
        "__COLANY__" => "(Column{Any}, Indexable{Any}, Iterable{Any}, ArrayOps{Any})",
        "__MCOL__" => "(Column{Float64}, MutableIndexable{Float64}, Iterable{Float64}, ArrayOps{Float64})",
        "__TAB__" => "TableSource",
        "__SAMPLE__" => "(Sample, Indexable{Float64}, Iterable{Float64}, ArrayOps{Float64})",
        "__POS__" => "(Positions, Indexable{Point2d}, Iterable{Point2d}, ArrayOps{Point2d})",
        "__COLOR__" => "(ColorSpec, Indexable{NTuple{4,Float64}}, Iterable{NTuple{4,Float64}}, ArrayOps{NTuple{4,Float64}})",
        "__GRAPH__" => "(GraphInterface{Int}, GraphOps{Int})", "__VDYN__" => "VertexDynamics", "__EDYN__" => "EdgeDynamics"))

const GROUPS = [
    ("base", "Base abstractarray.jl", ""),
    ("dataframes", "DataFrames (forks)", """
        using Tables
        using Tables.ColumnCore: Column, TableSource
        using DataFrames: DataFrames, GroupedDataFrame, Aggregate, groupreduce, groupreduce!, groupreduce!_helper,
                          copyto_widen!, fillfirst!, nrow, ncol, index, _names, ColumnIndex, AbstractDataFrame
        using Statistics: var, std
        """),
    ("makie", "MakieCompat", """
        using TraitMakie.PlotCore: Positions, Sample, ColorSpec
        using MakieCompat: Point2d, Point2, float_type, _isnanpoint, _nanpoint
        """),
    ("nd", "NetworkDynamics + Graphs", """
        using Graphs: Graphs, GraphInterface, nv, ne, edges, vertices, has_edge, degree, is_directed, outdegree,
                      indegree, neighbors, SimpleEdge, connected_components!
        using ..NDStubs
        using ..U1NDTraits
        """)]

"The samples of a file: (id, function name, source, original signature, first line, text)."
function samples(file)
    lines = readlines(file)
    out = []
    starts = findall(l -> startswith(l, "## "), lines)
    for (k, s) in enumerate(starts)
        stop = k < length(starts) ? starts[k+1] - 1 : length(lines)
        id, fn, src, orig = strip.(split(lines[s][4:end], " | "; limit = 4))
        push!(out, (; id, fn, src, orig, line = s + 1, text = join(lines[s+1:stop], "\n")))
    end
    return out
end

"The operation a checker problem names: what the body reaches outside the contract."
function reached(p::AbstractString)
    for (re, f) in (
            (r"is passed to `([^`]+)`, an ordinary function", m -> m[1]),
            (r"`([^`]+)` has no method for a trait object", m -> m[1]),
            (r"is passed to `([^`]+)`, whose methods need other traits", m -> m[1]),
            (r"passed to the builtin `([^`]+)`", m -> "builtin " * m[1]),
            (r"`t\.([^`]+)`(?: = …)?: the user's data", m -> "field ." * m[1]),
            (r"`t\.field`", m -> "field access"),
            (r"`typeof\(t\)`", m -> "typeof"),
            (r"stored in a tuple", m -> "tuple (kept in)"),
            (r"splatted into a call", m -> "splat"),
            (r"returns a trait object to ordinary code", m -> "returned (escapes)"),
            (r"a function not known at compile time", m -> "unknown function"),
            (r"inference stops at `([^`]+)`", m -> m[1] * " (undeclared arity, unreported)"))
        m = match(re, p)
        m === nothing && continue
        r = f(m)
        return occursin("Archetype", r) ? "constructs " * split(split(r, "{")[1], ".")[end] * "{typeof(t)}(t, …)" : r
    end
    return "other: " * p
end

# BaseTraits declares `@trait MutableIndexable{T} <: Indexable`: the supertrait's item type is left open in a
# bound, so `archetype_sig` defers every function bounded by `MutableIndexable{Float64}` to its first call
# (an open parameter). Here the supertrait's parameter is tied to the subtrait's (both are `eltype(Self)`), and
# the archetype is built as `archetype_tobj` builds it, from the list of patterns (a `Union` would fold
# `Indexable{Float64}` into the bare `Indexable`).
const MI = TraitWorld.BaseTraits.MutableIndexable
const IX = TraitWorld.BaseTraits.Indexable
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
"The archetype signature with MutableIndexable's supertrait parameter tied, or `nothing`."
function tied_archetype_sig(m::Method)
    sig = Base.unwrap_unionall(m.sig)
    sig isa DataType || return nothing
    ps = sig.parameters
    (isempty(ps) || ps[1] === typeof(Core.kwcall)) && return nothing
    out = Any[ps[1]]; bounded = false
    for k in 2:length(ps)
        p = ps[k]
        Base.isvarargtype(p) && return nothing
        lb = TW._tobj_lb(p)
        if lb === nothing || lb === Union{}
            push!(out, p isa TypeVar ? p.ub : p)
        else
            pats = tied_patterns(lb)
            any(u -> u isa UnionAll && TW._open_params(u), pats) && return nothing
            push!(out, tied_archetype_tobj(pats)); bounded = true
        end
    end
    return bounded ? Tuple{out...} : nothing
end

"The function a statement calls, with the trait objects among its argument types marked, or `nothing`."
function stop_callee(src, k)
    k === nothing && return nothing
    ex = src.code[k]
    ex isa Expr && ex.head === :(=) && (ex = ex.args[2])
    ex isa Expr && ex.head === :call || return nothing
    sp = src.parent isa Core.MethodInstance ? TW._CC.sptypes_from_meth_instance(src.parent) : TW._CC.EMPTY_SPTYPES
    fT = TW._CC.argextype(ex.args[1], src, sp)
    f = fT isa TW._CC.Const ? fT.val : nothing
    ats = [TW._CC.widenconst(TW._CC.argextype(a, src, sp)) for a in ex.args[2:end]]
    return string(f === nothing ? "?" : f, "(", join([TW._hastobj(a) ? "t" : "_" for a in ats], ", "), ")")
end

nameof_callee(c) = split(c, "(")[1]

"Check one function at archetypes: (status, problems, reached operations)."
function check(mod::Module, fn::Symbol)
    Base.invokelatest(isdefined, mod, fn) || return ("error", ["not defined"], String[], String[])
    f = Base.invokelatest(getfield, mod, fn)
    ps = String[]
    trunc = String[]
    nchecked = 0
    for m in methods(f)
        m.module === mod || continue
        asig = try TW.archetype_sig(m) catch e; (e,) end
        asig isa Tuple && (push!(ps, "archetype_sig failed: " * sprint(showerror, asig[1])); continue)
        if asig === nothing && any(p -> TW._tobj_lb(p) !== nothing, Base.unwrap_unionall(m.sig).parameters[2:end])
            asig = tied_archetype_sig(m)                              # deferred by an open supertrait parameter
            asig === nothing || push!(trunc, "tied")
        end
        asig === nothing && continue                                  # an entry, or a method without a bound
        nchecked += 1
        try
            append!(ps, Base.invokelatest(TW.worker_problems, asig)::Vector{String})
            # a call the contract does not answer may infer as `Union{}`: the code after it is dead to
            # inference and not checked, so the reached list is a lower bound for this method
            for (src, rt) in Base.code_typed_by_type(asig; optimize = false)
                # the statements that infer as `Union{}` with a trait object among the arguments: inference
                # stops there (a `throw` is a normal exit and is not counted)
                for k in findall(t -> t === Union{}, src.ssavaluetypes)
                callee = stop_callee(src, k)
                (callee === nothing || !occursin("t", split(callee, "(")[2])) && continue
                startswith(callee, "u_") && continue          # a sample's own other method: checked as itself
                push!(trunc, string(m.name, ":", m.line, " at ", callee))
                # a call that infers `Union{}` and that the checker passes (a contract's function at an arity
                # the contract does not declare): the body reaches it, and nothing after it is checked
                if true
                    fname = string(nameof_callee(callee))
                    any(p -> occursin("`$fname`", p) || occursin("`$(split(fname, '.')[end])`", p), ps) ||
                        push!(ps, "inference stops at `$callee` (Union{}), not reported by the checker")
                end
                end
            end
        catch e
            push!(ps, "checker failed: " * first(sprint(showerror, e), 300))
        end
    end
    nchecked == 0 && return ("unchecked", ps, String[], trunc)
    any(p -> startswith(p, "archetype_sig failed") || startswith(p, "checker failed"), ps) && return ("error", unique(ps), String[], trunc)
    ps = unique(ps)
    return (isempty(ps) ? "bounded" : "open", ps, unique(map(reached, ps)), trunc)
end

function run_variant(v::String)
    subst = VARIANTS[v]
    rows = []
    for (g, gname, usings) in GROUPS
        file = joinpath(HERE, "samples", "$g.jl")
        modname = Symbol("U1_", g, "_", v)
        Core.eval(Main, Meta.parse("""
            @trait_module module $modname
            using TraitWorld
            using ..U1Contracts
            $usings
            end
            """))
        mod = Base.invokelatest(getfield, Main, modname)
        for s in samples(file)
            text = s.text
            for (k, b) in subst
                text = replace(text, k => b)
            end
            err = nothing
            try
                include_string(mod, "\n"^(s.line - 1) * text, file)
            catch e
                err = first(sprint(showerror, e), 400)
            end
            st, ps, ops, trunc = err === nothing ? check(mod, Symbol(s.fn)) : ("error", ["definition failed: " * err], String[], String[])
            push!(rows, (; variant = v, group = g, s.id, s.fn, s.src, s.orig, status = st, ops, ps, trunc))
            println(rpad(s.id, 4), " ", rpad(v, 2), rpad(st, 10), rpad(s.fn, 26), join(ops, ", "),
                    "tied" in trunc ? "   [MutableIndexable's supertrait parameter tied]" : "",
                    isempty(setdiff(trunc, ["tied"])) ? "" : "   [inference stops (Union{}) in $(join(setdiff(trunc, ["tied"]), ", ")): reached list is a lower bound]")
            for p in ps
                println("        ", p)
            end
        end
    end
    open(joinpath(HERE, "logs", "results-$v.tsv"), "w") do io
        println(io, "variant\tgroup\tid\tfunction\tsource\toriginal\tstatus\treached\ttruncated\tproblems")
        for r in rows
            println(io, join((r.variant, r.group, r.id, r.fn, r.src, r.orig, r.status, join(r.ops, "; "), join(r.trunc, "; "),
                              join(replace.(r.ps, "\t" => " ", "\n" => " "), " || ")), "\t"))
        end
    end
    return rows
end

function summary(rows)
    for (g, gname, _) in vcat(GROUPS, [("all", "all samples", "")])
        rs = g == "all" ? rows : filter(r -> r.group == g, rows)
        n = length(rs)
        nb = count(r -> r.status == "bounded", rs); no = count(r -> r.status == "open", rs)
        nu = count(r -> r.status in ("unchecked", "error"), rs)
        nt = count(r -> !isempty(setdiff(r.trunc, ["tied"])), rs)
        nr = count(r -> r.status == "open" && all(==("returned (escapes)"), r.ops), rs)
        println("  ", rpad(gname, 26), "n=", n, "  fully bounded ", nb, "  open ", no, "  not checked ", nu,
                "  (open only by returning the argument: ", nr, "; with inference stopping at a Union{} call: ", nt, ")")
        if g == "all" || true
            cnt = Dict{String,Int}()
            for r in rs, o in r.ops
                cnt[o] = get(cnt, o, 0) + 1
            end
            ranked = sort(collect(cnt); by = x -> (-x[2], x[1]))
            println("      reached (functions reaching it): ", join(["$k $c" for (k, c) in ranked], ", "))
        end
    end
end

println("julia ", VERSION, " ", Base.GIT_VERSION_INFO.commit_short, "; TraitWorld ", pkgversion(TraitWorld))
allrows = []
for v in ("A", "B")
    println("\n=== variant $v ===")
    rows = run_variant(v)
    append!(allrows, rows)
    println("\n--- summary, variant $v ---")
    summary(rows)
end
println("\ntotal ", round(time() - t0; digits = 1), " s")
