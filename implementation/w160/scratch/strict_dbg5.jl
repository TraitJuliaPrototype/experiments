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
for mi in Base.specializations(only(methods(StrictLib.sq)))
    ci = mi.cache
    println(mi.specTypes, " ", typeof(ci.inferred))
    src = ci.inferred isa String || ci.inferred isa Vector{UInt8} ? Base._uncompressed_ir(ci) : ci.inferred
    src isa Core.CodeInfo && for (i, st) in enumerate(src.code); println("  ", i, " ", st, " :: ", src.ssavaluetypes[i]); end
end
