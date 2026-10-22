# P1a′: a family with a block over a variable, `@implement X A where {A <: S} begin … end`,
# outside the trait's module (by the type's owner) and inside it.
# Reference: traits §4.7 (a family with a block; declared by the trait's or the type's owner) with
# deviation T-57 (outside the trait's module refused by the rule-3 precheck).
include("common.jl")
header("P1a_prime", "@implement X A where {A <: S} begin … end, outside (by S's owner) and inside the trait's module")

toplevel(quote
    module ModelsA
    struct S{T}; x::T; end
    end
end)

# inside: the trait's module declares the family for the plain module's type
ein = caught(() -> toplevel(quote
    @trait_module module TraitIn
    using TraitWorld
    using ..ModelsA
    @trait Fam begin
        fval(s::Fam)::Float64
        fdef(s::Fam)::Float64 = 2 * fval(s)
    end
    usef(s::Fam) = fdef(s)
    @implement Fam A where {A <: ModelsA.S} begin
        fval(s) = Float64(s.x)
    end
    end
end))
println("inside: ", errtext(ein))

# outside: the trait's module, then the type's owner declares with a block
toplevel(quote
    @trait_module module TraitOut
    using TraitWorld
    @trait Fam2 begin
        fval2(s::Fam2)::Float64
    end
    usef2(s::Fam2) = fval2(s)
    end
end)
eout = caught(() -> toplevel(quote
    module ModelsB
    using TraitWorld
    using ..TraitOut
    struct S{T}; x::T; end
    @implement TraitOut.Fam2 A where {A <: S} begin
        fval2(s) = Float64(s.x)
    end
    end
end))
println("outside: ", errtext(eout))
println()

callres(f) = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end
show_r(r) = r[1] ? "returned $(repr(r[2]))" : errtext(r[2]; lines = 4)
r1 = callres(() -> TraitIn.usef(ModelsA.S(2)))
r1b = callres(() -> TraitIn.usef(ModelsA.S(1.5f0)))
println("inside: usef(S(2)) ", show_r(r1), "; usef(S(1.5f0)) ", show_r(r1b))
r2 = isdefined(Main, :ModelsB) ? callres(() -> TraitOut.usef2(ModelsB.S(2))) : (false, "ModelsB not defined")
println("outside: usef2(S(2)) ", show_r(r2))
println()

check("inside: accepted, members work (S{Int} gives 4.0, S{Float32} gives 3.0)",
      ein === nothing && r1 == (true, 4.0) && r1b == (true, 3.0), "inside: $(show_r(r1)), $(show_r(r1b))")
check("outside: refused by the rule-3 precheck (T-57)",
      eout isa ImplementError && occursin("rule 3", sprint(showerror, eout)), errtext(eout; lines = 3))

finish("P1a_prime";
    predicted = "outside: refused by the precheck (T-57); inside: works",
    reference = "traits §4.7: the trait's or the type's owner may declare a family with a block; Deviation T-57: outside the trait's module refused by the rule-3 precheck",
    prediction = "see the checks: yes where every check is ok")
