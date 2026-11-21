# W-158, fifth part: the build's check run in a session on a program (APP), then the instances of a function's methods
# (FN, default `mktrip`) the check made, by method: which arguments the forwarder was compiled at. PATCH=1 lays
# patch_i.jl over first. Run with the project of the library (wt/w158b-tw).
get(ENV, "PATCH", "0") == "1" && include(joinpath(@__DIR__, "patch_i.jl"))
include(ENV["APP"])
const CC = Base.Compiler
let world = Base.get_world_counter()
    mi = CC.specialize_method(Base._methods_by_ftype(Base.signature_type(main, (Vector{String},)), 1, world)[1])
    res = CC.closed_check(Any[mi], world, TraitWorld._build_base())
    println("check: ", count(e -> !e[1], res[1]), " errors")
    fn = getfield(Main, Symbol(get(ENV, "FN", "mktrip")))
    for m in methods(fn)
        println(m.sig)
        for s in Base.specializations(m)
            isdefined(s, :cache) || continue
            println("    ", s.specTypes)
        end
    end
end
