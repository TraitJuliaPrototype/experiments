using TraitWorld, BaseBenchmarks
const SRC = joinpath(pkgdir(BaseBenchmarks), "src", "problem")
include_string(Main, read(joinpath(SRC, "Raytracer.jl"), String))
include("/home/hellmann/Repos/julia-trait-bound/experiments/factscompiler/recovery/RTTrait.jl")
for (nm, f) in (("plain", Raytracer.perf_raytrace), ("trait", RTTrait.perf_raytrace))
    f(3, 8, 2)
    t = minimum(@elapsed(f(5, 64, 2)) for _ in 1:3); a = @allocated f(5, 64, 2)
    println(rpad(nm, 6), round(1000t; digits = 1), " ms, ", a ÷ 1000, " kB")
end
