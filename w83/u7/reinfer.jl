# E-255 (U7): the code the packages' images hold, inferred again under the counting Compiler.
#
# In a session, code from a package image is used as it is: its folds were made by the plain compiler
# while the image was written, and the suites' counts see only what the session compiles. This script
# loads the packages named in U7_PKGS (comma-separated), clears the counts, then infers every
# specialization of every method the packages define (all MethodInstances the session holds after
# loading, which includes those from the images) with `code_typed_by_type` (the reflection compiler is
# the counting one): each body once, its callees from the cache.
#     U7_PKGS=TraitTables,TraitCSV julia --project=<pkg> run.jl <tag> reinfer.jl
using Test
const PKGS = Symbol.(split(ENV["U7_PKGS"], ","))
for p in PKGS
    Core.eval(Main, :(using $p))
end
roots = Set{Module}(getfield(Main, p) for p in PKGS)
empty!(Compiler.U7_ALL); empty!(Compiler.U7_OPEN)
mis = Core.MethodInstance[]
Base.visit(Core.methodtable.defs) do m
    Base.moduleroot(m.module) in roots || return
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance && push!(mis, mi)
    end
end
println(stderr, "re-inferring ", length(mis), " method instances of ", PKGS)
nok = Ref(0); nerr = Ref(0)
t = @elapsed for mi in mis
    try
        Base.code_typed_by_type(mi.specTypes; optimize = true)
        nok[] += 1
    catch
        nerr[] += 1
    end
end
println(stderr, "re-inferred: $(nok[]) ok, $(nerr[]) errors, $(round(t; digits = 1)) s")
@test nok[] > 0
