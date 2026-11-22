# Gate (compiler §3.1, §4.8; C-161, E-541): a positive answer through an entry records every entry it rests on, also
# one whose member or set occurs only in a type variable's lower bound. In `Tuple{SZ, Ref{LY}} <: Tuple{LZ, Ref{T}}
# where T >: LX` the answer rests on `SZ in LZ` and on `LX in LY` (T = LY needs LX <: LY): the second's member is in
# the right side's lower bound, its set in the left side. Folded code records both, its worlds start at the later
# one, and taking that membership back ends it. A candidate for `gates/` (W-143e: `motiv/lb_entries.jl` as asserts);
# fails on `next` bfaf484f55, where the record held `SZ in LZ` alone.
#     julia --project=experiments/implementation f7_lower_bound_entries.jl
using Traits
function latest(f)
    out = Core.CodeInstance[]
    for mi in Base.specializations(only(methods(f)))
        isdefined(mi, :cache) || continue
        c = mi.cache
        while true
            c.owner === nothing && c.max_world == typemax(UInt) && push!(out, c)
            isdefined(c, :next) || break; c = c.next
        end
    end
    only(out)
end
entries(ci) = (es = ci.edges; [es[i+1].def for i in 1:length(es)-1 if es[i+1] isa Core.MethodInstance &&
               es[i+1].def isa Method && es[i+1].def.name === :implements && es[i] === es[i+1].def.sig])
folded(f) = (src = only(code_typed(f, ())).first; src.code[end] isa Core.ReturnNode && src.code[end].val === true)

@trait LZ8
@trait LX8
@trait LY8
struct SZ8 end
const A = Tuple{SZ8, Ref{LY8}}
const B = let T = TypeVar(:T, LX8, Any); UnionAll(T, Tuple{LZ8, Ref{T}}) end       # Tuple{LZ8, Ref{T}} where T >: LX8
const A3 = let T = TypeVar(:T, LY8, Any); UnionAll(T, Tuple{SZ8, Ref{T}}) end      # both sides' sets in lower bounds
const A1 = Ref{LY8}
const B1 = let T = TypeVar(:T, LX8, Any); UnionAll(T, Ref{T}) end                  # the lower bound alone
p() = A <: B
p3() = A3 <: B
p1() = A1 <: B1
fresh(a, b) = Base.inferencebarrier(a) <: Base.inferencebarrier(b)

e1 = @implement LZ8 SZ8
e2 = @implement LY8 LX8
@assert A <: B && A3 <: B && A1 <: B1
@assert Base.invoke_in_world(e2.min_world - 1, fresh, A, B) === false
for f in (p, p3, p1)
    @assert f()
    ci = latest(f)
    if folded(f)
        @assert e2.method in entries(ci) "$(f): the lower bound's entry in the record: $(entries(ci))"
        f === p1 || @assert e1.method in entries(ci) "$(f): the parameter's entry in the record"
        @assert ci.min_world >= e2.min_world "$(f): the worlds start at the later entry's"
    end
    @assert Base.invoke_in_world(e2.min_world - 1, f) === false "$(f): run in the world between the entries"
end
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), LX8, LY8, @__MODULE__)
@assert !(A <: B)
@assert p() === false && p3() === false && p1() === false "taken back: $(p()), $(p3()), $(p1())"
println("f7_lower_bound_entries: OK")
