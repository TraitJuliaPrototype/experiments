using TraitWorld
module StrictLib
using TraitWorld
@trait_module
@trait SBuf begin
    svals(r::SBuf)::Vector{Float64}
end
struct Buf; v::Vector{Float64}; end
svals(b::Buf) = b.v
@implement SBuf Buf
sq(b::SBuf) = (s = 0.0; for x in svals(b); s += abs2(x); end; s)
end
b = StrictLib.Buf([1.0,2.0,3.0])
StrictLib.sq(b)
ci = code_typed(StrictLib.sq, (StrictLib.Buf,), optimize=false)[1][1]
for (i, st) in enumerate(ci.code)
    println(i, " ", st, "  ::", ci.ssavaluetypes[i])
end
