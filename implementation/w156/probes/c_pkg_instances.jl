# W-156 third part: every instance with code of a package's methods after an app's `main` ran once, one per line
# (for a diff between two builds).   julia --project=<env> probes/c_pkg_instances.jl <Package> <app.jl> [args…]
pkg = Symbol(popfirst!(ARGS)); app = abspath(popfirst!(ARGS))
include(app)
redirect_stdout(devnull) do
    Base.invokelatest(main, ARGS)
end
out = String[]
Base.visit(Core.methodtable) do m
    nameof(Base.moduleroot(m.module)) === pkg || return
    for mi in Base.specializations(m)
        mi === nothing && continue
        isdefined(mi, :cache) || continue
        push!(out, string(mi.specTypes))
    end
end
foreach(println, sort!(out))
