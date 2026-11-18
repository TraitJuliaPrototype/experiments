# W-161, open issue 204's gate (E-497): a method written with the trait's parameters left open (`c::Column`) at a
# trait that erases by default erases too (traits §7.8). TraitTables' `summarize(c::Column, name)` of E-440: the
# method as written is compiled once per trait instance, not per member type; the forwarder boxes at the instance
# the member is in. A trait whose open parameter is an input (`Callable` written bare) takes the plain member as it
# is. Run with the library before the change and after it:
#     julia --project=<TraitWorld tree> summarize.jl
using TraitWorld, Test

module TC
using TraitWorld
@trait_module
@trait Column{T} begin
    @default_dynamic
    T = eltype(Self)
    nrows(c::Column)::Int
    cell(c::Column{T}, i::Int)::T
end
@implement Column{T} Vector{T} where {T} begin
    nrows(c) = length(c)
    cell(c, i) = c[i]
end
struct Ramp <: AbstractVector{Float64}; n::Int; end      # a second member type at Column{Float64}
Base.size(r::Ramp) = (r.n,)
Base.getindex(r::Ramp, i::Int) = Float64(i)
@implement Column{Float64} Ramp begin
    nrows(c) = c.n
    cell(c, i) = Float64(i)
end
function summarize(c::Column, name::String)     # the trait's parameter left open
    s = 0.0
    for i in 1:nrows(c)
        s += Float64(cell(c, i))
    end
    return string(name, ": ", nrows(c), " rows, sum ", s)
end
form(c::Column) = c isa Dynamic ? :boxed : c isa TraitWorld.Compiled ? :wrapped : :plain
applyit(f::Callable, x) = f(x)                  # Callable written bare: its parameters are inputs
callform(f::Callable, x) = f isa Dynamic ? :boxed : :plain
end

# the method of `summarize` as written (not the forwarder) and its instances
written(f) = [m for m in methods(f) if !TraitWorld._is_forwarder(m)]
instances(m::Method) = [mi for mi in Base.specializations(m) if mi isa Core.MethodInstance && isdefined(mi, :cache)]

@testset "open issue 204: a trait's parameters left open erase too" begin
    v, r, k = [1.0, 2.0, 3.0], TC.Ramp(4), [1, 2, 3]
    @test TC.summarize(v, "v") == "v: 3 rows, sum 6.0"
    @test TC.summarize(r, "r") == "r: 4 rows, sum 10.0"
    @test TC.form(v) === :boxed                   # a plain member is boxed at its instance
    @test TC.form(TraitWorld.ByType.compiled_for(v)) === :wrapped
    ms = written(TC.summarize)
    println("methods of summarize: ", length(methods(TC.summarize)), " (as written: ", length(ms), ")")
    @test length(ms) == 1
    m = only(ms)
    println("the method as written: ", m.sig)
    sigs = [mi.specTypes for mi in instances(m)]
    println("its instances after two member types at Column{Float64}: ", sigs)
    @test length(sigs) == 1                       # once for the instance, not per member type
    @test TC.summarize(k, "k") == "k: 3 rows, sum 6.0"
    sigs2 = [mi.specTypes for mi in instances(m)]
    println("after a member at Column{Int}: ", sigs2)
    @test length(sigs2) == 2                      # once per trait instance
    # a box and a wrapper reach the method as written as they are
    @test TC.summarize(Dynamic{TC.Column{Float64}}(r), "d") == "d: 4 rows, sum 10.0"
    @test length([mi for mi in instances(m)]) == 2
    # Callable written bare: an input left open, the plain member as it is
    @test TC.applyit(sin, 0.0) == 0.0
    @test TC.callform(sin, 0.0) === :plain
end
