# G1.16: a `Dynamic` operation in an older world computes what plain Julia computes in that world
# (identical or error; review 2026-10-18-design-and-fixes finding 2, the witness-table defect).
#
#     julia --project=../../examples/env g1_16_dynamic_world.jl
#
# Expected (design.md §4.5: an operation on a Dynamic dispatches in the caller's world): after
# implementations are redefined, a call pinned to the older world sees the old methods, and a call
# in the latest world the new ones; a conformance declared after the caller was compiled is seen
# in the latest world. With the package form of today (witness tables off by default) this should
# pass; part (D) moves the split into the compiler and must keep it passing.
include(joinpath(@__DIR__, "..", "..", "examples", "common.jl"))
using TraitWorld
toplevel(quote
    @trait_module module TS
    using TraitWorld
    export Shape, area, tsum, one_area, mk
    @trait Shape{R} begin
        area(r::R)::Float64
    end
    struct S1; a::Float64; end
    struct S2; a::Float64; end
    struct S3; a::Float64; end
    struct S4; a::Float64; end
    struct S5; a::Float64; end
    @implement Shape{S1} begin area(s) = 1.0 end
    @implement Shape{S2} begin area(s) = 2.0 end
    @implement Shape{S3} begin area(s) = 3.0 end
    @implement Shape{S4} begin area(s) = 4.0 end
    @implement Shape{S5} begin area(s) = 5.0 end
    tsum(v::Vector{Dynamic{Shape}}) = (s = 0.0; for d in v; s += area(d); end; s)
    one_area(d::Dynamic{Shape}) = area(d)
    mk(x) = Dynamic{Shape}(x)
    end
end)

d = Dynamic{TS.Shape}[TS.mk(TS.S1(0.0)), TS.mk(TS.S2(0.0)), TS.mk(TS.S3(0.0)), TS.mk(TS.S4(0.0)), TS.mk(TS.S5(0.0))]
check("G1.16 first call: tsum = 15.0", TS.tsum(d) == 15.0)
TS.one_area(d[5])
w0 = Base.get_world_counter()
Core.eval(TS, :(area(s::S1) = 100.0))
Core.eval(TS, :(area(s::S5) = 500.0))
r1 = Base.invokelatest(TS.tsum, d)
check("G1.16a after redefinitions, the latest world: tsum = 609.0", r1 == 609.0, "got $r1")
r_old = Base.invoke_in_world(w0, TS.tsum, d)
check("G1.16b the older world: tsum = 15.0 (the old methods)", r_old == 15.0, "got $r_old")
r_old1 = Base.invoke_in_world(w0, TS.one_area, d[5])
check("G1.16c the older world, one value: area = 5.0", r_old1 == 5.0, "got $r_old1")
Core.eval(TS, :(struct S6; a::Float64; end))
Core.eval(TS, :(@implement Shape{S6} begin area(s) = 6.0 end))
push!(d, Base.invokelatest(TS.mk, Base.invokelatest(TS.S6, 0.0)))
r2 = Base.invokelatest(TS.tsum, d)
check("G1.16d a conformance declared after the caller compiled: tsum = 615.0", r2 == 615.0, "got $r2")
r_old2 = outcome(() -> Base.invoke_in_world(w0, TS.one_area, d[6]))
check("G1.16e the older world does not see the later conformance (or the later type)", r_old2 isa Exception, "got $(r_old2 isa Exception ? typeof(r_old2) : r_old2)")
# To measure after (D): tsum over 10^6 values with 2, 5, 6 keys; per-element time against plain isa branches.
summary()
