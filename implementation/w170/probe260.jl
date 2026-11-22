# W-170 (E-538), open issue 260: what a declared field read through a box guarantees (traits §3.3, lowering §7),
# before and after the fix: a name outside the contract is refused, a value outside the declared type is refused,
# a write is converted to the declared type and refused at a `@const` field; at a constant name and at a name not
# constant. And whether the code compiled for a read at a constant name still computes the field's type.
#     julia --project=<env> probe260.jl
using TraitWorld, Test

@trait PHas{T} begin
    v::T
    @const w::Int
end
mutable struct PCell{T}; v::T; w::Int; z::Int; end
@implement PHas{T} PCell{T} where {T}
# a member whose property gives a value outside the declared type: the membership is checked against a right
# `getproperty`, which a later method replaces (a later method is not judged by the membership's check)
mutable struct PLiar; v::Float64; w::Int; end
Base.getproperty(l::PLiar, s::Symbol) = getfield(l, s)
@implement PHas{Float64} PLiar
Base.getproperty(l::PLiar, s::Symbol) = s === :v ? "not a Float64" : getfield(l, s)

readv(d) = d.v
readw(d) = d.w
readz(d) = d.z
readat(d, s) = getproperty(d, s)
writev!(d, x) = (d.v = x; nothing)
const NAMES = Symbol[:v, :w, :z]

@testset "the box's declared fields (open issue 260)" begin
    d = Dynamic{PHas{Float64}}(PCell(1.0, 2, 3))
    @test readv(d) === 1.0 && readw(d) === 2
    @test (@inferred readv(d)) === 1.0
    @test Base.return_types(readv, (Dynamic{PHas{Float64}},)) == [Float64]
    @test Base.return_types(readw, (Dynamic{PHas{Float64}},)) == [Int]
    @test propertynames(d) == (:v, :w)
    # a name outside the contract: refused, at a constant name and at one that is not
    e = try readz(d); nothing catch err; err end
    @test e isa ArgumentError && occursin("z is not a declared field of", sprint(showerror, e))
    @test readat(d, NAMES[1]) === 1.0 && readat(d, NAMES[2]) === 2
    e = try readat(d, NAMES[3]); nothing catch err; err end
    @test e isa ArgumentError && occursin("z is not a declared field of", sprint(showerror, e))
    # a value outside the declared type: refused, at a constant name and at one that is not
    l = Dynamic{PHas{Float64}}(PLiar(1.0, 2))
    @test_throws TypeError readv(l)
    @test_throws TypeError readat(l, NAMES[1])
    @test readw(l) === 2
    # writes: converted to the declared type; refused at a @const field and at a name outside the contract
    writev!(d, 5)
    @test unwrap(d).v === 5.0
    @test_throws MethodError writev!(d, "x")
    e = try d.w = 3; nothing catch err; err end
    @test e isa ArgumentError && occursin("declared @const", sprint(showerror, e))
    e = try d.z = 3; nothing catch err; err end
    @test e isa ArgumentError && occursin("not a declared field", sprint(showerror, e))
    # a parameter of the trait reaches the declared type
    di = Dynamic{PHas{Int}}(PCell(7, 2, 3))
    @test readv(di) === 7 && Base.return_types(readv, (Dynamic{PHas{Int}},)) == [Int]
    @test_throws TypeError readv(Dynamic{PHas{Int}}(PCell{Any}(1.5, 2, 3)))
end

# the code a read at a constant name compiles to: does it still compute the declared type when it runs?
ct = sprint(show, code_typed(readv, (Dynamic{PHas{Float64}},); optimize = true)[1])
println("R the read at a constant name: the box's getproperty called (its body computes the type when it runs): ",
        occursin("invoke Base.getproperty", ct), "; the type's computation in the caller: ",
        occursin("declared_field", ct) || occursin("_dynamic_field_type", ct))
println("R its typed code: ", replace(ct, r"\s+" => " ")[1:min(end, 600)])
