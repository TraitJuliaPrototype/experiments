using TraitWorld, InteractiveUtils
module T
using TraitWorld
@trait_module first_seen = false
@trait Model begin
    @default_dynamic
    rate(m::Model, u::Float64)::Float64
end
@noinline step2(m::Model, u::Float64) = u + 1e-9 * rate(m, u)
end
module U
using TraitWorld
import ..T: Model, rate
struct Decay; k::Float64; end
rate(d::Decay, u::Float64) = -d.k * u
@implement Model Decay
end
c1(m::U.Decay, u::Float64) = T.step2(m, u)
println(Base.return_types(c1, (U.Decay, Float64)))
println(Base.return_types(T.step2, (U.Decay, Float64)))
println(Base.return_types(T.step2, (T.Model, Float64)))
println(Base.return_types(c1, (U.Decay, Float64)))
code_typed(c1, (U.Decay, Float64)) |> println
