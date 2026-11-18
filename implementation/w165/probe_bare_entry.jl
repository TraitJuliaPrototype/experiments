# W-165, out of scope (open issue 238, first case): an entry at the bare name of a set whose parameter is no input
#     <julia> --startup-file=no --project=experiments/implementation probe_bare_entry.jl
using Traits
@trait Z{P}
struct S end
declare_membership(S, Z, Main)                   # the stub's `@implement Z S`: an entry at the bare name
h(::Z{1}) = 1
h(::Z{2}) = 2
println("S <: Z{1}: ", S <: Z{1}, ", S <: Z{2}: ", S <: Z{2}, "; Z{1} ∩ Z{2} = ", typeintersect(Z{1}, Z{2}))
println("isambiguous(h at Z{1}, h at Z{2}) = ", Base.isambiguous(which(h, (Z{1},)), which(h, (Z{2},))),
        "; h(S()) -> ", try h(S()) catch e; typeof(e) end)
