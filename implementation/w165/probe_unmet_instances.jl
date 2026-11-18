# W-165 (E-503): what the lookup does at an abstract query where a method at another instance of the set is met
# only at the unmet `All{X{A}, X{B}}` (compiler §4.8, §5.4), against the same question for two different sets.
#     <julia> --startup-file=no --project=experiments/implementation probe_unmet_instances.jl
using Traits
const CC = Base.Compiler
lookup(T) = CC.findall(T, CC.method_table(CC.NativeInterpreter()); limit = -1)
unmet(T) = ccall(:jl_has_unmet_argument, Cint, (Any, UInt), T, Base.get_world_counter()) != 0
dyn(f, T) = count(st -> Meta.isexpr(st, :call) || Meta.isexpr(st, :invoke) && false, first(only(code_typed(f, T))).code)
@trait HP{N, R}
ccall(:jl_set_input_params, Cvoid, (Any, UInt8), HP, 0x01)
struct One end
declare_membership(One, HP{:a, Int}, Main)
g(::HP{:a, Int}) = :a
g(::HP{:b, String}) = :b
r = lookup(Tuple{typeof(g), HP{:a, Int}})
println("instances: unmet(All{HP{:a,Int}, HP{:b,String}}) = ", unmet(Tuple{typeof(g), Core.All{Tuple{HP{:a, Int}, HP{:b, String}}}}),
        "; lookup at HP{:a, Int}: ambig = ", r.ambig, ", matches = ", length(r.matches), ", cells = ", r.cells)
cg(@nospecialize(x::HP{:a, Int})) = g(x)
println("  caller at HP{:a, Int}: ", first(only(code_typed(cg, (HP{:a, Int},)))))
@trait X1
@trait Y1
struct M1 end
declare_membership(M1, X1, Main)
k(::X1) = :x
k(::Y1) = :y
r = lookup(Tuple{typeof(k), X1})
println("two sets: unmet(All{X1, Y1}) = ", unmet(Tuple{typeof(k), Core.All{Tuple{X1, Y1}}}),
        "; lookup at X1: ambig = ", r.ambig, ", matches = ", length(r.matches), ", cells = ", r.cells)
ck(@nospecialize(x::X1)) = k(x)
println("  caller at X1: ", first(only(code_typed(ck, (X1,)))))
