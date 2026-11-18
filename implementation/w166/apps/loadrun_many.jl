# W-166 (open issue 241): trait code run while the build loads it, at a trait with six members: an operation's call
# on a value known only by its trait branches on the first four in a session and takes the table past them (traits §7.9).
module Many
using TraitWorld
@trait_module
export Sh, ar
@trait Sh begin
    ar(s::Sh)::Float64
end
end
using .Many, TraitWorld
for (i, n) in enumerate((:S1, :S2, :S3, :S4, :S5, :S6))
    @eval struct $n; x::Float64; end
    @eval Many.ar(s::$n) = $(Float64(i)) * s.x
    @eval @implement Sh $n
end
total(v::Vector{Sh}) = (t = 0.0; for s in v; t += ar(s); end; t)
const SHAPES = Sh[S1(1.0), S2(1.0), S3(1.0), S4(1.0), S5(1.0), S6(1.0)]
println(Core.stdout, "at load: ", total(SHAPES))
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, "total ", total(Sh[S1(1.0), S6(2.0)]))
    return 0
end
