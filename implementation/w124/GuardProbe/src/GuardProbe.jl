# E-319: a guarded call kept in a package image, so the census can be checked on image code.
module GuardProbe
using TraitWorld
@trait Zp
struct Wp end
hp(x) = 1
hp(z::Zp)::Float64 = 2.0
callp(w::Wp) = hp(w)
callp(Wp())
precompile(callp, (Wp,))
end
