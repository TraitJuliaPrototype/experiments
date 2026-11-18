# W-165 (E-503): the library's `HasProperty{N, R}` (BaseTraits; `N` an input) under the rule of compiler §4.9.
# A type that is a member at two names: two methods at `HasProperty{:a, T}` and `HasProperty{:b, U}` tie for it;
# a type at one name keeps its method; two instances at one name that differ in `R` are disjoint.
#     cd TraitWorld && <julia> --startup-file=no --project=. ../experiments/implementation/w165/hasproperty.jl
using TraitWorld
const HP = TraitWorld.HasProperty
struct AB165
    a::Int
    b::String
end
struct A165
    a::Int
end
@implement HP{:a, Int} AB165
@implement HP{:b, String} AB165
@implement HP{:a, Int} A165
show_ti(x, y) = println(rpad("$x ∩ $y", 64), " = ", typeintersect(x, y))
show_ti(HP{:a, Int}, HP{:b, String})
show_ti(HP{:a, Int}, HP{:a, String})
show_ti(HP{:a, T} where T, HP{:b, U} where U)
show_ti(HP{N, Int} where N, HP{:a, String})
prop(x::HP{:a, T}) where {T} = :a
prop(x::HP{:b, U}) where {U} = :b
ma = which(prop, (HP{:a, Int},)); mb = which(prop, (HP{:b, String},))
outcome(f) = try f() catch e; e isa MethodError ? "MethodError" : "$(typeof(e))" end
println("isambiguous(prop at :a, prop at :b) = ", Base.isambiguous(ma, mb))
println("prop(AB165(1, \"x\")) -> ", outcome(() -> prop(AB165(1, "x"))), "   (a member at both names: a tie)")
println("prop(A165(1)) -> ", outcome(() -> prop(A165(1))), "   (a member at :a only)")
same(x::HP{:a, Int}) = :int
same(x::HP{:a, String}) = :string
println("isambiguous(same at :a Int, same at :a String) = ", Base.isambiguous(which(same, (HP{:a, Int},)), which(same, (HP{:a, String},))))
println("same(A165(1)) -> ", outcome(() -> same(A165(1))))
both(x::Core.All{Tuple{HP{:a, Int}, HP{:b, String}}}) = :both
both(x::HP{:a, Int}) = :a
println("both(AB165(1, \"x\")) -> ", outcome(() -> both(AB165(1, "x"))), "; both(A165(1)) -> ", outcome(() -> both(A165(1))))
println("hasproperty: OK")
