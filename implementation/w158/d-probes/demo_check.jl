# W-158, piece 1: the bounded check over the demonstrators' modules (TraitTables, the ODE port and its libraries,
# TraitMakie): every method at a trait read at the box, bounded scope or not (`TraitWorld.check_definitions`), the
# faults listed. Run before and after a change of the check, to see what it reads anew.
#     $JN --project=$W158/env_demo_d $W158/d-probes/demo_check.jl
using TraitWorld, TraitTables, TraitDifferentialEquations, TraitMakie
println("pathof ", pathof(TraitWorld), "  commit ", readchomp(`git -C $(dirname(dirname(pathof(TraitWorld)))) log -1 --format=%h`),
        isempty(readchomp(`git -C $(dirname(dirname(pathof(TraitWorld)))) status --short src`)) ? "" : "+dirty")
mods = Module[]
for m in Base.loaded_modules_array()
    f = pathof(m)
    f === nothing && continue
    any(d -> occursin("/$d/", f), ("TraitTables", "TraitDifferentialEquations", "TraitMakie")) && push!(mods, m)
end
function submodules!(acc, M)
    for n in names(M; all = true)
        isdefined(M, n) || continue
        v = getglobal(M, n)
        v isa Module && v !== M && parentmodule(v) === M && !(v in acc) && (push!(acc, v); submodules!(acc, v))
    end
    return acc
end
for M in copy(mods)
    submodules!(mods, M)
end
total = 0
for M in sort(unique(mods); by = string)
    ps = TraitWorld.check_definitions(M)
    global total += length(ps)
    # the methods read at the box, and those among them with a vararg of members
    nread = nva = 0
    for n in names(M; all = true)
        isdefined(M, n) || continue
        f = try getglobal(M, n) catch; continue end
        (f isa Function || f isa Type) || continue
        for m in methods(f)
            (m.module === M && TraitWorld._at_box_checked(m)) || continue
            nread += 1
            sig = TraitWorld.box_signature(m)
            sig isa DataType && any(Base.isvarargtype, sig.parameters) && any(p -> p isa Core.TypeofVararg && isdefined(p, :T) && p.T <: Dynamic, sig.parameters) && (nva += 1; println("   vararg of members: ", m))
        end
    end
    println("== ", M, ": ", nread, " methods read at the box, ", nva, " with a vararg of members; ", length(ps), " faults")
    foreach(p -> println("   ", p), ps)
end
println("total ", total, " faults in ", length(unique(mods)), " modules")
