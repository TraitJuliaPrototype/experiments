# W-158, the port's part: the build's check of the ODE program run in the session (as ../probes/ode_members.jl),
# each error with its whole chain of frames, outermost last: where the program reaches it.
include(joinpath(@__DIR__, "..", "..", "..", "w135", "apps", "ode.jl"))
const CC = Base.Compiler
let world = Base.get_world_counter()
    mi = CC.specialize_method(Base._methods_by_ftype(Base.signature_type(main, (Vector{String},)), 1, world)[1])
    res = CC.closed_check(Any[mi], world, TraitWorld._build_base())
    V = CC.TrimVerifier
    for (w, e) in res[1]
        w && continue
        fr = V.verify_create_stackframes(e.codeinst, e.stmtidx, res[2])
        println("error: ", e.desc, " | ", join([string(f.func, " ", basename(string(f.file)), ":", f.line) for f in fr], " <- "))
    end
end
