# W-158, the other ports: the build's check run in the session on the nonlinear program (../apps/nl.jl), as
# `../../probes/ode_members.jl` does for the ODE program: its errors, with the frame of each. Project ../../w156/env_demo.
include(joinpath(@__DIR__, "..", "apps", get(ENV, "NLAPP", "nl") * ".jl"))
const CC = Base.Compiler
let world = Base.get_world_counter()
    mi = CC.specialize_method(Base._methods_by_ftype(Base.signature_type(main, (Vector{String},)), 1, world)[1])
    t = @elapsed res = CC.closed_check(Any[mi], world, TraitWorld._build_base())
    errs = res[1]
    println("check: ", count(e -> !e[1], errs), " errors, ", count(e -> e[1], errs), " calls that only raise, ",
            length(res) >= 4 ? res[4] : "?", " rounds, ", round(t; digits = 1), " s")
    length(res) >= 3 && for (X, ms) in res[3]
        println("  ", X, ": ", length(ms), " members: ", join(string.(ms), ", "))
    end
    V = CC.TrimVerifier
    for (w, e) in errs
        w && continue
        fr = V.verify_create_stackframes(e.codeinfo === nothing ? e.codeinst : e.codeinst, e.stmtidx, res[2])
        println("  error: ", e.desc, " at ", isempty(fr) ? "?" : string(fr[1].file, ":", fr[1].line), " | ",
                first(sprint(io -> V.verify_print_stmt(io, e.codeinfo, e.sptypes, e.stmtidx)), 900))
    end
end
