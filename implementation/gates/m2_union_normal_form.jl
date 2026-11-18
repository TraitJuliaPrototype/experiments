# Gate (compiler §4.9; the review of 2026-11-07, finding 7): a membership never absorbs a component
# of a Union, so a type expression gives the same type object in every world.
using Traits
include("util.jl")

@trait PZ
struct S2 end
u1 = Union{S2, PZ}
@implement PZ S2
u2 = Union{S2, PZ}
@assert S2 <: PZ
@assert u1 === u2 && u2 isa Union
@assert Union{Int, Integer} === Integer             # a declared supertype still absorbs

println("m2_union_normal_form: OK")
