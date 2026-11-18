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
@show StrictLib.sq(b)
mi = Base.method_instance(StrictLib.sq, (StrictLib.Buf,))
ci = mi.cache
while ci !== nothing
  println("ci flags=", getfield(ci, :flags), " owner=", ci.owner, " edges=", ci.edges)
  global ci = isdefined(ci, :next) ? ci.next : nothing
end
for e in StrictLib.sq.name.mt === nothing ? () : ()
end
