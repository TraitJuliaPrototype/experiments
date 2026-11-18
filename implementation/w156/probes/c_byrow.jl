# W-156 third part (compiler C-112): probes/byrow.jl with the library's exported compiled_for (the first part's probe imports it from TraitWorld.ByType, which is gone): the forks' byrow with its function plain, wrapped and boxed.
# the results, and the instance of `byrow` that ran (its first argument's type).
#     julia --project=env_session probes/byrow.jl
using Tables, TraitWorld

const CC = Tables.ColumnCore
f(x) = 2x
c = [1, 2, 3]
for (name, g) in (("plain", f), ("wrapper", compiled_for(f)), ("box", Dynamic{Callable{Tuple{Int}, Int}}(f)))
    r = try
        CC.byrow(g, c)
    catch e
        sprint(showerror, e)[1:min(end, 200)]
    end
    ran = [string(mi.specTypes.parameters[2]) for m in methods(CC.byrow) for mi in Base.specializations(m)
           if mi !== nothing && isdefined(mi, :cache) && length(mi.specTypes.parameters) == 3]
    println(rpad(name, 8), " ", repr(r), " | byrow's instances with code: ", unique(ran))
end
# a type as the function (Tables' own suite: `ByRow(Dict)`)
println("Type{Dict} a Callable{Tuple{Pair{Int,Int}}}: ", Dict isa Callable{Tuple{Pair{Int,Int}}})
println("ByRow(Dict): ", try Tables.ByRow(Dict)([1 => 2, 3 => 4]) catch e sprint(showerror, e)[1:min(end, 200)] end)
println("ByRow(identity): ", Tables.ByRow(identity)([1 => 2, 3 => 4]))
