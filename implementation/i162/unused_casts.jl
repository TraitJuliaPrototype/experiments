# Open issue 162 (c): the casts without effect in a port's modules (TraitWorld.detect_unused_casts),
# and a reproducer of the case that found the issue (NetworkDynamics' batch call before 7e8997d).
#   julia --project=<env> unused_casts.jl <Package> [<Package> …]
using TraitWorld
module Repro
using TraitWorld
@trait Model begin
    @default_dynamic
    step(m::Model, x::Float64)::Float64
end
struct M1 end
@implement Model M1 begin
    step(m::M1, x::Float64) = x + 1
end
struct Batch; model::Dynamic{Model}; end
run_batch_untyped(m, x) = step(m, x)              # the cast at its caller has no effect here
run_batch_typed(m::Model, x) = step(m, x)
callers(b::Batch, x) = run_batch_untyped(compiled_for(b.model), x) + run_batch_typed(compiled_for(b.model), x)
end
println("Repro: ", [(m.name, line, k) for (m, line, f, k) in detect_unused_casts(Repro)])
for p in Symbol.(ARGS)
    @eval using $p
    mod = getfield(Main, p)
    t = @elapsed r = detect_unused_casts(mod)
    println(p, ": ", length(r), " unused casts (", round(t, digits = 1), " s)")
    for (m, line, f, k) in r
        println("    ", m.module, ".", m.name, " line ", line, ": argument ", k, " of a call to ", f)
    end
end
