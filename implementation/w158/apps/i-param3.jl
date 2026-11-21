# W-158, fifth part (E-510; traits §8.2): apps/i-ctor3.jl with the record made before the signatures are known in
# the form of traits §8.2's example (`ODEFunction{F, TJ, TMM}`, upstream's `DiscreteCallback{F1, F2, F3, F4}`): a
# struct parametric in its functions' types, so that the code that enters it knows each function's type and the
# constructor's forwarder runs at those types. No value is known only by bare `Callable`: the build makes no split
# for it. The functions are known where the records are made (as the ODE program's callbacks are); records of
# functions picked at run time would be of many types (open issue 245).
# `julia --project=<TraitWorld> apps/i-param3.jl` runs `main` in a session.
include(joinpath(@__DIR__, "i-ctor3.jl"))
struct Rec3{C, A, I}
    c::C
    a::A
    i::I
end
@noinline enterp(rs::Vector) = (s = 0.0; for r in rs; s += usetrip(mktrip(r.c, r.a, r.i)); end; s)
function (@main)(args::Vector{String})::Cint
    n = length(args)
    println(Core.stdout, "fixed ", enterp([Rec3(c2, a3, i4)]) + enterp([Rec3(c5, a1, i2)]))
    return 0
end
