# A system image of the patched Julia with TraitWorld in it ("the policy in the platform", session 26).
# Run with --sysimage <patched sys.so> --output-o: TraitWorld is loaded from source, its precompile block
# compiles the policy's compiler for FactsInterp and the machinery's slow paths under the policy.
Sys.__init_build()                  # BINDIR and STDLIB are empty while generating output
Base.init_depot_path()
Base.init_load_path()
using TraitWorld
# a small trait module at a fresh key, so the policy's inference runs end to end once more
@trait_module module SysWarm
using TraitWorld
@trait Len begin
    len(x::Len)::Int
end
@implement Len Vector{Float64} begin
    len(x) = length(x)
end
twice(x::Len) = 2 * len(x)
end
SysWarm.twice([1.0, 2.0])
# no paths baked into the image
empty!(LOAD_PATH)
empty!(DEPOT_PATH)
@eval Sys BINDIR = ""
@eval Sys STDLIB = ""
