# E-255 (U7): the abstract types that some `@implement X A where {A <: F}` ranges over (a family's
# abstract type F), read from TraitWorld's implementation and projection methods after loading the
# packages named on the command line; appended to families.tsv as "module<TAB>name".
#     julia --project=<pkg> families.jl Pkg1 Pkg2 ...
for p in ARGS
    Core.eval(Main, :(using $(Symbol(p))))
end
const TW = Base.require(Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld"))
out = Set{Tuple{Symbol,Symbol}}()
for f in (TW.implementation, TW.projection), m in methods(f)
    sig = Base.unwrap_unionall(m.sig)
    length(sig.parameters) >= 3 || continue
    R = sig.parameters[3]
    R isa DataType && R.name === Base.typename(Type) || continue
    v = R.parameters[1]
    v isa TypeVar || continue
    ub = Base.unwrap_unionall(v.ub)
    for u in Base.uniontypes(ub)
        u = Base.unwrap_unionall(u)
        u isa DataType && isabstracttype(u) || continue
        # a family over a trait is a generic implementation: counted as a trait already
        u <: TW.Trait && continue
        push!(out, (nameof(u.name.module), u.name.name))
    end
end
open(joinpath(@__DIR__, "families.tsv"), "a") do io
    for (m, n) in sort!(collect(out))
        println(io, m, '\t', n, '\t', join(ARGS, ","))
    end
end
println(sort!(collect(out)))
exit()
