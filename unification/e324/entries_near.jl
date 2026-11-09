# E-324: the membership entries that begin in a window of worlds after a load, by member type and set: what splits
# the worlds between a package's method definitions and its image's instances.
#   julia --project=<env> entries_near.jl <lo> <hi> Pkg1,Pkg2,...
lo, hi = parse(Int, ARGS[1]), parse(Int, ARGS[2])
for p in split(ARGS[3], ','); @eval using $(Symbol(p)); end
println("world ", Base.get_world_counter())
seen = Set{Any}()
function visit(m::Module)
    m in seen && return; push!(seen, m)
    for n in names(m; all = true)
        isdefined(m, n) || continue
        v = try getfield(m, n) catch; continue end
        if v isa Module && parentmodule(v) === m && v !== m
            visit(v)
        elseif v isa Union{DataType, UnionAll} && Base.unwrap_unionall(v) isa DataType
            tn = Base.unwrap_unionall(v).name
            tn in seen && continue; push!(seen, tn)
            for en in getfield(tn, :memberships)
                w = en.min_world
                lo <= w <= hi && println(w, "  ", tn.module, ".", tn.name, " in ", en.set, "  member ", en.member)
            end
        end
    end
end
foreach(visit, (Base, Core, values(Base.loaded_modules)...))
