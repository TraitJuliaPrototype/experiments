# §18 of writeup/intro/traits-by-example.md: strict mode refuses a pirate that would change code
# compiled by facts. In its own process, since it changes Base's methods. Run from TraitWorld-unified/:
#   JULIA_PKG_OFFLINE=true nice -n 19 ../julia-unified/julia --project=. --startup-file=no ../experiments/docs-examples/strict.jl
include(joinpath(@__DIR__, "common.jl"))
using TraitWorld

module Norms
using TraitWorld
@trait_module
export Values, vals, sq
@trait Values begin
    vals(v::Values)::Vector{Float64}
end
@implement Values Vector{Float64} begin
    vals(v) = v
end
sq(v::Values) = (s = 0.0; for x in vals(v); s += abs2(x); end; s)
end
using .Norms

check("§18 sq([1.0, 2.0, 3.0])", sq([1.0, 2.0, 3.0]) == 14.0)
TraitWorld.strict!(true)            # or start Julia with JULIA_TW_STRICT=1
e = thrown(quote
    module Meddler2
    Base.abs2(x::Float64) = 2.0 * x * x      # Base's function, Base's type: a pirate
    end
end)
check("§18 the pirate is refused: PirateError", e isa TraitWorld.PirateError)
e isa Exception && println("      message: ", replace(first(msg(e), 500), '\n' => " | "))
check("§18 sq is unchanged", Base.invokelatest(sq, [1.0, 2.0, 3.0]) == 14.0)
check("§18 the pirate was never defined", abs2(2.0) == 4.0)
e = thrown(:(module Meddler3; Base.abs2(x::Int8) = Int8(7); end))
check("§18 a pirate that changes no code compiled by facts is accepted", e === nothing)
TraitWorld.strict!(false)

summary()
