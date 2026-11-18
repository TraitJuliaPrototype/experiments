# E-407, the baseline's path at E-402's row (TraitWorld-base: the attribute, code compiled once): what the caller
# passes, what it allocates a call, and the caller's LLVM IR to `logs/baseline-ir.ll`.
#     julia --project=<TraitWorld-base> baseline.jl
using TraitWorld, InteractiveUtils
module T
using TraitWorld
@trait_module
@trait Model begin
    @default_dynamic
    rate(m::Model, u::Float64)::Float64
end
@noinline step(m::Model, u::Float64) = u + 1e-9 * rate(m, u)
end
module U
using TraitWorld
import ..T: Model, rate
struct Decay; k::Float64; end
rate(d::Decay, u::Float64) = -d.k * u
@implement Model Decay
end
call1(m::U.Decay, u::Float64) = T.step(m, u)
loop(fw, d, n) = (u = 1.0; for _ in 1:n; u = fw(d, u); end; u)
alloc_of(fw, x) = (fw(x, 1.0); @allocated fw(x, 1.0))
const N = 10^7
const SINK = Ref(0.0)
ns(h, args...) = minimum(@elapsed(SINK[] += h(args..., N)) for _ in 1:7) / N * 1e9
d = U.Decay(0.5)
loop(call1, d, 10); call1(d, 1.0)
println(rpad("the attribute", 16), "ns a call ", round(ns(loop, call1, d); digits = 2), "   bytes a call ", alloc_of(call1, d))
open(joinpath(@__DIR__, "logs", "baseline-ir.ll"), "w") do io
    code_llvm(io, call1, (U.Decay, Float64); debuginfo = :none)
end
