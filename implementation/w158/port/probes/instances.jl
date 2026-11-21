# W-158 port (a copy of ../../../w156/instances.jl with the ODE port's packages; W-156, E-504): the compiled instances the session's packages hold. Loads an app of `../w135/apps/`, runs its
# `main` once, then counts, per package (TraitTables, TraitCSV, TraitMakie, TraitWorld), the method instances of
# the package's methods that hold code (a CodeInstance), and of them those at a kept form (`Dynamic`, `Compiled`).
#     julia --project=env_demo instances.jl <app.jl> [args…]        (LIST=1: TraitTables' and TraitCSV's instances at a kept form)
app = abspath(popfirst!(ARGS))
include(app)
redirect_stdout(devnull) do
    Base.invokelatest(main, ARGS)
end
const PKGS = (:ODECore, :TraitRodas, :TraitDifferentialEquations, :TraitIndexing, :TraitWorld)
counts = Dict(p => [0, 0, 0] for p in PKGS)       # instances with code, at a kept form, methods
kept(@nospecialize(t)) = occursin(r"\b(Dynamic|Compiled)\{", string(t))
Base.visit(Core.methodtable) do m
    p = nameof(Base.moduleroot(m.module))
    p in PKGS || return
    c = counts[p]; c[3] += 1
    for mi in Base.specializations(m)
        mi === nothing && continue
        isdefined(mi, :cache) || continue
        c[1] += 1
        kept(mi.specTypes) && (c[2] += 1; get(ENV, "LIST", "0") == "1" && p in (:ODECore, :TraitRodas) && println("kept-form instance ", mi.specTypes))
    end
end
for p in PKGS
    c = counts[p]
    println("instances $p: $(c[1]) with code, $(c[2]) of them at a kept form; $(c[3]) methods")
end
