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
# the snapshot is taken at the workload's "load" mark, so code that came with the loaded images is not counted
_on_mark(step) = step == "load" && (_BEFORE[] = _cis(); nothing)
const _SCRIPT, _OUT, _STMTS = ARGS[1], ARGS[2], ARGS[3]
empty!(ARGS); push!(ARGS, _OUT)
include(joinpath(@__DIR__, "..", _SCRIPT))
let after = _cis(), kept = Set{String}(), owners = Dict{Any,Int}(), named = 0, total = 0, unprintable = 0
    for ci in after
        ci in _BEFORE[] && continue
        total += 1
        owners[ci.owner] = get(owners, ci.owner, 0) + 1
        mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
        mi.def isa Method || continue
        T = mi.specTypes
        if _names_main(T); named += 1; continue; end
        str = try sprint(show, T; context = :module => Core) catch; nothing end
        str === nothing ? (unprintable += 1) : push!(kept, "precompile(" * str * ")")
    end
    open(_STMTS, "w") do io
        foreach(l -> println(io, l), sort!(collect(kept)))
    end
    println("R new CodeInstances ", total, " by owner ", owners, "; naming Main ", named, "; unprintable ", unprintable, "; statements kept ", length(kept))
end
