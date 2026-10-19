# Step 5: what a forwarding `@implement` costs in a clean session, with only TraitWorld loaded,
# or after other packages (LOADS="TraitMakie"), and what it infers.
#     julia --project=<env with TraitWorld, SnoopCompileCore> implement_alone.jl
using TraitWorld
for p in split(get(ENV, "LOADS", "")); Core.eval(Main, Meta.parse("using " * p)); end
using SnoopCompileCore
struct Fwd1; label::String; v::Vector{Float64}; end
struct Fwd2; v::Vector{Float64}; n::Int; end
tinf = @snoop_inference @eval @implement TraitWorld._PC.PCT Fwd1 by v
r1 = @timed @eval @implement TraitWorld._PC.PCT Fwd2 by v
println("loads: [", get(ENV, "LOADS", ""), "]  second @implement: ", round(1000r1.time; digits = 1), " ms (compile ", round(1000r1.compile_time; digits = 1),
        "); first: inference ", round(1000 * sum(c -> SnoopCompileCore.inclusive(c), tinf.children; init = 0.0); digits = 1), " ms in ", length(tinf.children), " roots")
for c in sort(tinf.children; by = c -> -SnoopCompileCore.inclusive(c))[1:min(end, 30)]
    mi = c.ci.def isa Core.MethodInstance ? c.ci.def : c.ci.def.def
    println("   ", lpad(round(1000 * SnoopCompileCore.inclusive(c); digits = 1), 6), " ms  ", first(string(mi.specTypes), 140), "  owner=", repr(c.ci.owner))
end
