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
call_once_ni(m::U.Decay, u::Float64) = @noinline T.step2(m, u)
code_warntype(call_once_ni, (U.Decay, Float64))
code_warntype(T.step2, (T.Model, Float64))
