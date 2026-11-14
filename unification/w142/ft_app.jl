# W-142: the session's check of a program: julia --project=<env> ft_app.jl <app.jl>
Base.include(Main, abspath(ARGS[1]))
t = @elapsed r = TraitWorld.fully_typed(main, (Vector{String},))
println("VERDICT ", isfullytyped(r) ? "fully typed" : "not: $(length(r.sites)) sites", "  ", round(t; digits=1), " s")
isfullytyped(r) || show(stdout, MIME"text/plain"(), r)
println(); exit(0)
