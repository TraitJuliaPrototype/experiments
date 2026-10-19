ENV["N"] = "10"
include("/home/hellmann/Repos/julia-trait-bound/experiments/factscompiler/recovery/dynmicro.jl")
fi = Base.Compiler.NativeInterpreter(Base.get_world_counter(); facts = true, owner = :facts)
src, rt = only(Base.code_typed_by_type(Tuple{typeof(TS.tsum), Vector{Dynamic{TS.Shape}}}; interp = fi))
println(src)
