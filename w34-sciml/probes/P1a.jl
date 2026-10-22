# P1a: a family with a block, `@implement X S{T} where {T} begin … end`, inside and outside the
# trait's module; and the joint form with a block, `@implement SV{T} Ser{T} where {T} begin … end`.
# Reference: traits §4.7 (a family may come with a block) with deviation T-5 (not lowered as a
# family when the target is a parametric type expression: a call raises MethodError with the hint).
include("common.jl")
header("P1a", "@implement X S{T} where {T} begin … end (and the joint X{T} Ser{T} where {T} begin … end), inside and outside the trait's module")

# the model types: plain modules (owners of their own)
toplevel(quote
    module ModelsA
    struct S{T}; x::T; end
    struct Ser{T}; data::Vector{T}; end
    end
end)

# inside: the trait's module declares the families for the plain module's types (one module per form,
# so that one refusal does not hide the other)
ein = caught(() -> toplevel(quote
    @trait_module module TraitIn
    using TraitWorld
    using ..ModelsA
    @trait Fam begin
        fval(s::Fam)::Float64
    end
    usef(s::Fam) = fval(s)
    @implement Fam ModelsA.S{T} where {T} begin
        fval(s) = Float64(s.x)
    end
    end
end))
println("inside, family with a block: ", errtext(ein))
ein2 = caught(() -> toplevel(quote
    @trait_module module TraitIn2
    using TraitWorld
    using ..ModelsA
    @trait SV{T} begin
        sget(s::SV{T}, i::Int)::T
    end
    uses(s::SV{T}) where {T} = (T, sget(s, 1))
    @implement SV{T} ModelsA.Ser{T} where {T} begin
        sget(s, i) = s.data[i]
    end
    end
end))
println("inside, joint family with a block: ", errtext(ein2))

# outside: the trait's module first, then the type's owner declares
toplevel(quote
    @trait_module module TraitOut
    using TraitWorld
    @trait Fam2 begin
        fval2(s::Fam2)::Float64
    end
    @trait SV2{T} begin
        sget2(s::SV2{T}, i::Int)::T
    end
    usef2(s::Fam2) = fval2(s)
    uses2(s::SV2{T}) where {T} = (T, sget2(s, 1))
    end
end)
eout1 = caught(() -> toplevel(quote
    module ModelsB
    using TraitWorld
    using ..TraitOut
    struct S{T}; x::T; end
    @implement TraitOut.Fam2 S{T} where {T} begin
        fval2(s) = Float64(s.x)
    end
    end
end))
println("outside, family with a block: ", errtext(eout1))
eout2 = caught(() -> toplevel(quote
    module ModelsC
    using TraitWorld
    using ..TraitOut
    struct Ser{T}; data::Vector{T}; end
    @implement TraitOut.SV2{T} Ser{T} where {T} begin
        sget2(s, i) = s.data[i]
    end
    end
end))
println("outside, joint family with a block: ", errtext(eout2))
println()

callres(f) = (r = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end; r)
r1 = isdefined(Main, :TraitIn) ? callres(() -> TraitIn.usef(ModelsA.S(2))) : (false, "TraitIn not defined")
r2 = isdefined(Main, :TraitIn2) ? callres(() -> TraitIn2.uses(ModelsA.Ser([1.5]))) : (false, "TraitIn2 not defined")
r3 = isdefined(Main, :ModelsB) ? callres(() -> TraitOut.usef2(ModelsB.S(2))) : (false, "ModelsB not defined")
r4 = isdefined(Main, :ModelsC) ? callres(() -> TraitOut.uses2(ModelsC.Ser([1.5]))) : (false, "ModelsC not defined")
show_r(r) = r[1] ? "returned $(repr(r[2]))" : errtext(r[2]; lines = 4)
for (lbl, r) in (("inside, family", r1), ("inside, joint", r2), ("outside, family", r3), ("outside, joint", r4))
    println(lbl, ": call ", show_r(r))
end
println()

# T-5 says: the declaration is accepted, no member gets an implementation, a call raises MethodError (the hint)
t5(e, r) = e === nothing && !r[1] && r[2] isa MethodError
check("inside, family with a block: declared, call raises MethodError (T-5)", t5(ein, r1), "declaration: $(errtext(ein; lines = 2)); call: $(show_r(r1))")
check("inside, joint family with a block: declared, call raises MethodError (T-5)", t5(ein2, r2), "declaration: $(errtext(ein2; lines = 2)); call: $(show_r(r2))")
check("outside, family with a block: declared, call raises MethodError (T-5)", t5(eout1, r3), "declaration: $(errtext(eout1; lines = 2)); call: $(show_r(r3))")
check("outside, joint family with a block: declared, call raises MethodError (T-5)", t5(eout2, r4), "declaration: $(errtext(eout2; lines = 2)); call: $(show_r(r4))")

finish("P1a";
    predicted = "not a family in either module: a call reports \"conforms to none\" (T-5)",
    reference = "traits §4.7: a family may take a block; Deviation T-5: `S{P} where {P}` with a block is taken as one type (the UnionAll); a call raises MethodError with the hint",
    prediction = "see the checks: yes where every check is ok")
