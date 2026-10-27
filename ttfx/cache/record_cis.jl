# E-175: run a workload script and record every CodeInstance the session created after its load step (all owners),
# as precompile statements for those whose MethodInstance names no type of Main.
#     julia [flags] cache/record_cis.jl <workload.jl or workload_d.jl> <outdir> <statements file>
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
_names_main(@nospecialize(T)) =
    T isa Union ? (_names_main(T.a) || _names_main(T.b)) :
    T isa UnionAll ? (_names_main(T.var.lb) || _names_main(T.var.ub) || _names_main(T.body)) :
    T isa TypeVar ? (_names_main(T.lb) || _names_main(T.ub)) :
    T isa Core.TypeofVararg ? (isdefined(T, :T) && _names_main(T.T)) :
    T isa DataType ? (parentmodule(T) === Main || any(_names_main, T.parameters)) :
    T isa Tuple ? any(_names_main, T) : false
const _BEFORE = Ref{Any}(nothing)
# E-177: with REC_SOLVER set, the solver library is loaded first; the packages the rest of the load brings are the
# plotting part's, and a recorded type that names one of them goes to the plotting part of the cache
const _SOLVER_MODS = if haskey(ENV, "REC_SOLVER")
    foreach(n -> Base.require(Main, Symbol(n)), split(ENV["REC_SOLVER"], ",")); Set{Module}(values(Base.loaded_modules))
else
    nothing
end
const _PLOT_MODS = Ref{Set{Module}}(Set{Module}())
_mentions(@nospecialize(T), mods::Set{Module}) =
    T isa Union ? (_mentions(T.a, mods) || _mentions(T.b, mods)) :
    T isa UnionAll ? (_mentions(T.var.lb, mods) || _mentions(T.var.ub, mods) || _mentions(T.body, mods)) :
    T isa TypeVar ? (_mentions(T.lb, mods) || _mentions(T.ub, mods)) :
    T isa Core.TypeofVararg ? (isdefined(T, :T) && _mentions(T.T, mods)) :
    T isa DataType ? (Base.moduleroot(parentmodule(T)) in mods || any(p -> _mentions(p, mods), T.parameters)) :
    T isa Tuple ? any(p -> _mentions(p, mods), T) : false
# the snapshot is taken at the workload's "load" mark, so code that came with the loaded images is not counted
_on_mark(step) = step == "load" && (_BEFORE[] = _cis();
    _SOLVER_MODS === nothing || (_PLOT_MODS[] = setdiff(Set{Module}(values(Base.loaded_modules)), _SOLVER_MODS)); nothing)
const _SCRIPT, _OUT, _STMTS = ARGS[1], ARGS[2], ARGS[3]
empty!(ARGS); push!(ARGS, _OUT)
include(joinpath(@__DIR__, "..", _SCRIPT))
using Serialization
let after = _cis(), kept = Set{String}(), owners = Dict{Any,Int}(), named = 0, total = 0, unprintable = 0, plainT = Any[], factsT = Any[], checkT = Any[]
    for ci in after
        ci in _BEFORE[] && continue
        total += 1
        owners[ci.owner] = get(owners, ci.owner, 0) + 1
        mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
        mi.def isa Method || continue
        T = mi.specTypes
        if _names_main(T); named += 1; continue; end
        str = try sprint(show, T; context = :module => Core) catch; nothing end
        # code of the facts owner is replayed for that owner (`fpc`, defined by the cache module); `precompile` would
        # compile plain copies of Base methods, not the facts copies the session uses
        ci.owner === :facts ? push!(factsT, T) : ci.owner === nothing && push!(plainT, T)
        fn = ci.owner === :facts ? "fpc(" : "precompile("
        str === nothing ? (unprintable += 1) : push!(kept, fn * str * ")")
    end
    if get(ENV, "RECORD_LIST", "") != ""
        open(ENV["RECORD_LIST"], "w") do io
            for ci in after
                ci in _BEFORE[] && continue
                mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
                println(io, ci.owner, "\t", mi.def isa Method ? mi.def.module : "-", "\t", mi.specTypes)
            end
        end
    end
    # the first-call checks the session ran (TraitWorld): kept with the code, so a later session skips them
    checks = String[]
    for (id, m) in Base.loaded_modules
        id.name == "TraitWorld" || continue
        for sig in getglobal(m, :_CHECKED_IN_SESSION)
            _names_main(sig) && continue
            push!(checkT, sig)
            str = try sprint(show, sig; context = :module => Core) catch; nothing end
            str === nothing || push!(checks, "checked(" * str * ")")
        end
    end
    open(_STMTS, "w") do io
        foreach(l -> println(io, l), sort!(collect(kept)))
        foreach(l -> println(io, l), unique(checks))
    end
    println("R checks kept ", length(unique(checks)))
    # the types themselves: printing loses trait objects' types (TraitWorld prints them by bound and key)
    serialize(replace(_STMTS, r"\.jl$" => ".jls"), (plain = unique(plainT), facts = unique(factsT), checks = unique(checkT)))
    if _SOLVER_MODS !== nothing      # E-177: the split by dependency set
        P = _PLOT_MODS[]
        part(v, plot) = unique(filter(T -> _mentions(T, P) == plot, v))
        for (plot, suffix) in ((false, "-solver"), (true, "-plot"))
            serialize(replace(_STMTS, r"\.jl$" => suffix * ".jls"),
                      (plain = part(plainT, plot), facts = part(factsT, plot), checks = part(checkT, plot)))
        end
        println("R split: plotting part's packages ", length(P), "; solver part ", length(part(plainT, false)) + length(part(factsT, false)),
                " types, plotting part ", length(part(plainT, true)) + length(part(factsT, true)))
    end
    println("R new CodeInstances ", total, " by owner ", owners, "; naming Main ", named, "; unprintable ", unprintable, "; statements kept ", length(kept))
end
