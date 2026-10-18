# Struct redefinition and conformance redeclaration at the prompt (the review's example 14;
# design.md §4.4). What happens today, against what the design says.
#
#     julia --project=../env prompt.jl
#
# Expected (design.md §4.4):
#   1 a conforming struct redefined (Julia 1.13 allows it): old values keep the old type and its
#     conformance; the new type conforms once `@implement` is declared for it; before that, a call
#     with a new value is a TraitBoundError naming the bound.
#   2 a conformance redeclared with a different set of overrides: "needs a restart until
#     redeclaration is built" — a clear error that says so; the old conformance stays in force.
#   3 an implementation method redefined (not the conformance): followed (G1.1).
#   4 the redeclaration itself, built like struct redefinition: pending (not built).
include(joinpath(@__DIR__, "..", "common.jl"))
using TraitWorld
toplevel(quote
    @trait_module module RD
    using TraitWorld
    export Sh, area, label, describe
    @trait Sh begin
        area(s::Sh)::Float64
        label(s::Sh)::String = "shape"
    end
    describe(s::Sh) = string(label(s), " of area ", area(s))
    end
end)
# 1. a struct redefinition
toplevel(quote
    struct Sq; a::Float64; end
    RD.area(s::Sq) = s.a^2
    @implement RD.Sh Sq
end)
old = Base.invokelatest(() -> Main.Sq(2.0))
check("1 before: describe(Sq(2.0))", Base.invokelatest(RD.describe, old) == "shape of area 4.0")
r = outcome(() -> (toplevel(:(struct Sq; a::Float64; b::Float64; end)); nothing))
check("1 Julia 1.13 redefines the struct", r === nothing, r === nothing ? "" : sprint(showerror, r))
new = Base.invokelatest(() -> Main.Sq(2.0, 3.0))
check("1 the old value keeps the old type", typeof(old) !== typeof(new))
o1 = outcome(() -> Base.invokelatest(RD.describe, old))
check("1 the old value still conforms, with the old method", o1 == "shape of area 4.0", "got $(o1 isa Exception ? typeof(o1) : o1)")
n1 = outcome(() -> Base.invokelatest(RD.describe, new))
check("1 the new type does not conform yet: a TraitBoundError naming the bound", n1 isa TraitBoundError && occursin("Sh", sprint(showerror, n1)),
      n1 isa Exception ? first(sprint(showerror, n1), 200) : "got $n1")
r = outcome(() -> (toplevel(quote
    RD.area(s::Sq) = s.a * s.b
    @implement RD.Sh Sq
end); nothing))
check("1 the new type conforms after its own @implement", r === nothing, r === nothing ? "" : first(sprint(showerror, r), 300))
n2 = outcome(() -> Base.invokelatest(RD.describe, new))
check("1 the new value: describe uses the new method", n2 == "shape of area 6.0", "got $(n2 isa Exception ? typeof(n2) : n2)")
o2 = outcome(() -> Base.invokelatest(RD.describe, old))
check("1 the old value: still the old method", o2 == "shape of area 4.0", "got $(o2 isa Exception ? typeof(o2) : o2)")

# 2. a conformance redeclared with an override of a default
toplevel(quote
    struct Ci; r::Float64; end
    RD.area(c::Ci) = 3.0 * c.r^2
    @implement RD.Sh Ci
end)
c = Base.invokelatest(() -> Main.Ci(1.0))
check("2 before: the default label", Base.invokelatest(RD.describe, c) == "shape of area 3.0")
e2 = outcome(() -> (toplevel(quote
    @implement RD.Sh Ci begin
        label(c) = "circle"
    end
end); nothing))
msg2 = e2 isa Exception ? sprint(showerror, e2) : ""
println("     redeclaration: ", e2 === nothing ? "accepted" : first(msg2, 300))
d2 = outcome(() -> Base.invokelatest(RD.describe, c))
if e2 === nothing
    check("2 a redeclaration accepted is in force consistently", d2 == "circle of area 3.0", "got $(d2 isa Exception ? typeof(d2) : d2)")
else
    check("2 the redeclaration is refused with an error that says why (restart or redeclaration)",
          occursin(r"restart|redeclar|already", msg2), first(msg2, 300))
    check("2 the old conformance stays in force", d2 == "shape of area 3.0", "got $(d2 isa Exception ? typeof(d2) : d2)")
end
# 2b. the override written as a plain method after the conformance (design.md §4.4: refused,
#     naming the fix), on a fresh type so that case 2's outcome does not matter
toplevel(quote
    struct Ci2; r::Float64; end
    RD.area(c::Ci2) = 3.0 * c.r^2
    @implement RD.Sh Ci2
end)
e2b = outcome(() -> (toplevel(:(RD.label(c::Ci2) = "circle")); nothing))
msg2b = e2b isa Exception ? sprint(showerror, e2b) : ""
check("2b an override after the conformance is refused, naming the operation", e2b isa ImplementError && occursin("label", msg2b), first(msg2b, 300))
check("2b the message names a fix", occursin(r"@implement|restart|block", msg2b), first(msg2b, 300))
c2 = Base.invokelatest(() -> Main.Ci2(1.0))
check("2b the default stays in force", Base.invokelatest(RD.describe, c2) == "shape of area 3.0")

# 3. an implementation method redefined
toplevel(:(RD.area(c::Ci2) = 3.14 * c.r^2))
check("3 a redefined implementation method is followed", Base.invokelatest(RD.describe, c2) == "shape of area 3.14")
pending("4 a conformance redeclared at the prompt, old values and worlds answering as before",
        "conformance redeclaration (design.md §4.4: to build, by the struct-redefinition mechanism)")
summary()
