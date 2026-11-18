# W-156 third part: the instances with code that an app's `main` adds in the packages (TraitTables, TraitCSV,
# TraitMakie, TraitWorld, Base, Core), by method: what the session compiled that the images did not hold.
#     julia --project=env_demo probes/c_session_new.jl <app.jl> [args…]
app = abspath(popfirst!(ARGS))
include(app)
function snapshot()
    s = Set{Any}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi === nothing && continue
            isdefined(mi, :cache) || continue
            push!(s, mi)
        end
    end
    return s
end
before = snapshot()
redirect_stdout(devnull) do
    Base.invokelatest(main, ARGS)
end
after = snapshot()
new = [mi for mi in after if !(mi in before)]
println("new instances with code: ", length(new))
for mi in sort!(new; by = mi -> string(mi.def.module, " ", mi.specTypes))
    println("  ", Base.moduleroot(mi.def.module), " | ", mi.specTypes)
end
