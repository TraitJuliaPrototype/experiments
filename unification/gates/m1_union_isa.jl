# Gate for review finding M3: a type value with an entry for Type{S} (compiler §4.10)
# answers `isa U` when some arm of the union U contains the set, as dispatch does.
using Traits
include("util.jl")

@trait Z9
struct Mem9 end
@implement Z9 Mem9                    # the type's values
@implement Z9 Type{Mem9}              # and the type value

@assert (Mem9 isa Z9) "bare set (baseline)"
@assert (Mem9 isa Union{Z9, Int}) "type value answers through a union containing the set"
@assert !(Mem9 isa Union{String, Int}) "unrelated union stays false (exact)"

h(::Union{Z9, Int}) = :hit
h(::Any) = :miss
@assert h(Mem9) === :hit "dispatch matches the arm"
@assert (Mem9() isa Union{Z9, Float64}) "value isa through the union arm too"

println("m1_union_isa: OK")
