# A known hit for census.jl (U5_SELFTEST=1): U5B adds a bounded method to U5A's `ga` for its set XB, whose
# members Float64 (shielded by U5A's typed `ga(::AbstractFloat)`) and String (unshielded) are foreign.
@trait_module module U5A
using TraitWorld
export XA, ga, opa
@trait XA begin
    opa(x::XA)::Int
end
ga(x::XA) = opa(x)
ga(x::AbstractFloat) = 0
@implement XA Int begin opa(x) = 1 end
end
@trait_module module U5B
using TraitWorld
import ..U5A
@trait XB begin
    opb(x::XB)::Int
end
@implement XB Float64 begin opb(x) = 2 end
@implement XB String begin opb(x) = 3 end
U5A.ga(x::XB) = opb(x)
U5A.ga(x::(U5A.XA, XB)) = opb(x)
end
@assert U5A.ga("a") == 3 && U5A.ga(1.0) == 0 && U5A.ga(1) == 1
