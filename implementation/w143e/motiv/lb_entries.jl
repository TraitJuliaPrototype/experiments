# W-143e (E-541; compiler C-161): a positive answer through an entry, about types where a set occurs only in a type
# variable's lower bound. Inference folds `A <: B` where it can record the entries the answer rests on
# (`record_memberships!`, `jl_membership_entries_for`: the entries on a TypeName reachable from A whose set reaches
# a set that B names). In `Tuple{SZ, Ref{LY}} <: Tuple{LZ, Ref{T}} where T >: LX` the answer rests on two
# entries: SZ in LZ (a parameter) and LX in LY (the bound: T = LY needs LX <: LY). The second has its member
# in B's lower bound and its set in A, so a walk of A's TypeNames against B's sets, upper bounds only, misses it.
# Does the code compiled before the second entry ends still return `true`?
#     julia --project=experiments/implementation motiv/lb_entries.jl        (the stub library)
using Traits
curworld() = Base.tls_world_age()
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
# the memberships a CodeInstance rests on: `invoke` edges to their methods of `Core.implements` (compiler §5.6)
entries(ci) = (es = ci.edges; [es[i+1].def for i in 1:length(es)-1 if es[i+1] isa Core.MethodInstance &&
               es[i+1].def isa Method && es[i+1].def.name === :implements && es[i] === es[i+1].def.sig])
folded(f) = (src = only(code_typed(f, ())).first; src.code[end] isa Core.ReturnNode && src.code[end].val === true)
del(member, set) = ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), member, set, @__MODULE__)

@trait LZ
@trait LX
@trait LY
struct SZ end
const A = Tuple{SZ, Ref{LY}}
const B = let T = TypeVar(:T, LX, Any); UnionAll(T, Tuple{LZ, Ref{T}}) end    # Tuple{LZ, Ref{T}} where T >: LX
# (2) the set in the lower bound alone: nothing else to rest a fold on
const A1 = Ref{LY}
const B1 = let T = TypeVar(:T, LX, Any); UnionAll(T, Ref{T}) end               # Ref{T} where T >: LX
# (3) both lower bounds: ∀T ≥ LY, Ref{T} <: Ref{T2} with T2 ≥ LX, i.e. LX <: LY
const A3 = let T = TypeVar(:T, LY, Any); UnionAll(T, Tuple{SZ, Ref{T}}) end
p() = A <: B          # defined before the memberships, so that an older world can call them
p1() = A1 <: B1
p3() = A3 <: B
fresh(a, b) = Base.inferencebarrier(a) <: Base.inferencebarrier(b)     # asked when it runs, not folded

bit(t) = ccall(:jl_has_open_set, Cint, (Any,), t)
println("bit: A ", bit(A), " | B ", bit(B), " | B1 ", bit(B1), " | A3 ", bit(A3))
w0 = curworld()
e1 = @implement LZ SZ
e2 = @implement LY LX           # LX joins LY
println("asked afresh: A <: B ", A <: B, " | A1 <: B1 ", A1 <: B1, " | A3 <: B ", A3 <: B)
println("asked in the world between the entries: A <: B ", Base.invoke_in_world(e2.min_world - 1, fresh, A, B),
        " | A1 <: B1 ", Base.invoke_in_world(e2.min_world - 1, fresh, A1, B1), " | A3 <: B ", Base.invoke_in_world(e2.min_world - 1, fresh, A3, B))
for (name, f) in (("p", p), ("p1", p1), ("p3", p3))
    r = f()
    ci = latest(f)
    ents = entries(ci)
    println(name, "(): ", r, " | folded ", folded(f), " | entries in the record: ",
            ents == [] ? "none" : join([e === e1.method ? "SZ in LZ" : e === e2.method ? "LX in LY" : string(e) for e in ents], ", "),
            " | code's min_world ", ci.min_world >= e2.min_world ? ">= the second entry's" : ci.min_world >= e1.min_world ? ">= the first entry's only" : "below both")
    println("   run in the world between the entries: ", Base.invoke_in_world(e2.min_world - 1, f))
end
del(LX, LY)                     # the second entry taken back (compiler §4.3): its method is deleted
println("after LX in LY is taken back: asked afresh A <: B ", A <: B, " | A3 <: B ", A3 <: B)
println("   p() ", p(), " | p1() ", p1(), " | p3() ", p3(), "   (each must be false)")
