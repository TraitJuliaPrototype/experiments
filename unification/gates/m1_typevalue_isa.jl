# Gate M1-d (compiler §4.10, C-19): a type value is a member of a set only by an entry
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

println("m1_typevalue_isa: OK")
