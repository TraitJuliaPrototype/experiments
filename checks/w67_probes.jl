# W-67's probes (the clean-up W-65; closed open issues §3, "behind the notes" item 6, and open §3 item 2):
#   (1) fully typed mode traces an abstract value to a key's field type, an abstract declared field, as its root cause;
#   (2) definition checking at an archetype meets a constructor whose parameter is bounded (`SimpleEdge{T<:Integer}`)
#       with the trait's open parameter: no false problem, and the call runs.
#     julia --project=<TraitWorld> w67_probes.jl
using TraitWorld

println("--- (1) a root cause through a key's field type")
@trait_module module RootKey
using TraitWorld
export HasData, total
@trait HasData begin
    @const data::AbstractVector          # an abstract declared field: the key's field type
end
@warn_not_fully_typed total(h::HasData) = (s = 0.0; for x in h.data; s += x; end; s)
end
struct RK; data::Vector{Float64}; end
@implement RootKey.HasData RK
println("P1 result: ", RootKey.total(compiled_for(RK([1.0, 2.0]))))   # at the type's own key; the warning, with its root causes, goes to stderr

println("--- (2) a parameter-bounded constructor at an archetype")
struct SimpleEdge{T <: Integer}
    src::T
    dst::T
end
@trait_module module PBound
using TraitWorld
using ..Main: SimpleEdge
export Graph, nv, edge1
@trait Graph{T} begin
    nv(g::Graph)::T
end
edge1(g::Graph{T}) where {T} = SimpleEdge{T}(nv(g), nv(g))
end
struct G3; n::Int; end
@implement PBound.Graph{Int} G3 begin
    nv(g) = g.n
end
e = try
    PBound.edge1(G3(3))
catch err
    "raised: " * first(sprint(showerror, err), 300)
end
println("P2 result: ", e)
