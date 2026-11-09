# Gate M1-d (compiler §4.10, C-19, C-70): a type value is a member of a set only by an entry
# whose pattern is Type{S}, kept on S's TypeName. An entry for S answers S <: X and
# `S() isa X`, never `S isa X`; an entry for Type{S} answers `S isa X`, never `S <: X`.
using Traits
include("util.jl")

@trait X4
struct Late4 end
struct Late4b end

vprobe(y) = y isa X4                  # defined early: callable in both worlds

w_old = curworld()
@assert !(Late4 <: X4) && !(Late4 isa X4) && !(Late4() isa X4) "nothing before the declarations"

@implement X4 Late4                   # the type is a member
@assert (Late4 <: X4) "the entry answers Late4 <: X4"
@assert (Late4() isa X4) "and its values"
@assert !(Late4 isa X4) "the type value is not a member (A1)"
@assert !isa(Late4, X4)

@implement X4 Type{Late4b}            # the type value is a member
@assert (Late4b isa X4) "a Type{S} entry answers S isa X"
@assert vprobe(Late4b) "through a function compiled before the declaration"
@assert !(Late4b <: X4) "and never S <: X"
@assert !(Late4b() isa X4) "nor its values"
@assert !Base.invoke_in_world(w_old, vprobe, Late4b) "old world: false"
@assert typeintersect(Type{Late4b}, X4) == Type{Late4b} "intersection sees the type value's entry"
@assert typeintersect(Type{Late4}, X4) == Union{} "and no entry for Late4's value"
@assert !(Int isa X4) && !(1 isa X4)

# C-70: a kind of type object meets a set that takes a type value, by its own entry or that of a
# set that joins it; inference and dispatch at an argument typed by the kind find the set's method,
# in a caller compiled before the set took a type value too
tv(::X4) = :set
tv(::Any) = :any
kind_site(x::DataType) = tv(x)
@assert typeintersect(DataType, X4) !== Union{} "DataType meets a set with a type value"
@assert kind_site(Late4b) === :set && kind_site(Int) === :any
@assert Base.return_types(kind_site, (DataType,)) == Any[Symbol]
@trait X5
tv5(::X5) = :set
tv5(::Any) = :any
kind_site5(x::DataType) = tv5(x)
@assert kind_site5(Int) === :any
@assert typeintersect(DataType, X5) === Union{} "no type value: disjoint"
struct Late5 end
@implement X5 Type{Late5}
@assert kind_site5(Late5) === :set "a caller compiled before the declaration"
@assert kind_site5(Int) === :any
@trait X6
@implement X6 X5                      # X5 joins X6
tv6(::X6) = :set
tv6(::Any) = :any
kind_site6(x::DataType) = tv6(x)
@assert typeintersect(DataType, X6) !== Union{} "through a set that joins it"
@assert kind_site6(Late5) === :set && kind_site6(Int) === :any

println("m1_typevalue_isa: OK")
