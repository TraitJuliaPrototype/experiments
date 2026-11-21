# W-158, fifth part (a copy of ../f-probes/ode_members.jl; PATCH=1 lays patch_i.jl over; APP=<file> another program): the ODE program's `main` (../../w135/apps/ode.jl), the build's check run in the session:
# its rounds, its members at each set type a split was made at, its seconds and its errors. `PATCH=1` lays the
# worktree's change over the session's compiler first (`patch_c.jl`). Run with the project ../../w156/env_demo.
get(ENV, "PATCH", "0") == "1" && include(joinpath(@__DIR__, "patch_i.jl"))
include(get(ENV, "APP", joinpath(@__DIR__, "..", "..", "w135", "apps", "ode.jl")))
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
        fr = V.verify_create_stackframes(e.codeinst, e.stmtidx, res[2])
        println("  error: ", e.desc, " at ", isempty(fr) ? "?" : string(fr[1].file, ":", fr[1].line), " | ",
                first(sprint(io -> V.verify_print_stmt(io, e.codeinfo, e.sptypes, e.stmtidx)), 300))
    end
end
