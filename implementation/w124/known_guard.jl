# a guarded call, as gate n16's section (2): the census must find it
using Traits
@trait Zg
struct Wg end
hg(x) = 1
hg(z::Zg)::Float64 = 2.0
callhg(w::Wg) = hg(w)
@assert callhg(Wg()) === 1
