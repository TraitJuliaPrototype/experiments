# Step 3, (b) against (c), without the machinery: an untyped call site (elements of a Vector{Any})
# reaching the worker for one key, `w(data::Vector{Float64})`, from three user types of that key.
#   (b) one dynamic dispatch to code specialized per type; the view folds to a field read.
#   (c) a table at the site: type => the field's offset; the view read through the offset
#       intrinsic; the worker reached through a caller-world pointer (step 1). No code per type.
#   (c') as (c), the worker called directly: the bound on (c) if the site knew the key.
#   plain: the same work in plain Julia, one dynamic dispatch.
#     julia --project=<env with TraitWorld, BenchmarkTools> c_estimate.jl
using TraitWorld, BenchmarkTools
struct SA; name::String; data::Vector{Float64}; end
mutable struct SB; n::Int; data::Vector{Float64}; end
struct SC; data::Vector{Float64}; end
struct SD; a::Int; b::Int; data::Vector{Float64}; end   # a fourth type: plain inference speculates over at most three methods
@noinline w(d::Vector{Float64}) = @inbounds d[1] + d[end]      # the worker, compiled once for the key

gb(x::SA) = w(x.data); gb(x::SB) = w(x.data); gb(x::SC) = w(x.data); gb(x::SD) = w(x.data)      # (b): per type
pl(x) = @inbounds x.data[1] + x.data[end]                                  # plain, specialized per type

const W = TraitWorld.dynamic_fn(Tuple{Vector{Float64}}, Float64, w)       # a caller-world pointer
struct Entry; T::DataType; off::Int; end
const TABLE = Entry[Entry(SA, Int(fieldoffset(SA, 2))), Entry(SB, Int(fieldoffset(SB, 2))), Entry(SC, Int(fieldoffset(SC, 1))), Entry(SD, Int(fieldoffset(SD, 3)))]
@inline function _lookup(@nospecialize(x))
    T = typeof(x)
    @inbounds for i in 1:length(TABLE)
        e = TABLE[i]
        e.T === T && return Core.Intrinsics.getfield_at_offset(x, Vector{Float64}, e.off)::Vector{Float64}
    end
    error("no implementation")
end
# the entry compiled once at Any, with no call that takes `x::Any` (builtins and the intrinsic
# only), so that under the facts rule nothing in it is a run-time site
macro lookup(x)
    quote
        T = typeof($(esc(x)))
        tbl = TABLE
        d = nothing
        i = 1
        while i <= length(tbl)
            e = @inbounds tbl[i]
            if e.T === T
                d = Core.Intrinsics.getfield_at_offset($(esc(x)), Vector{Float64}, e.off)::Vector{Float64}
                break
            end
            i += 1
        end
        d === nothing && error("no implementation")
        d::Vector{Float64}
    end
end
gc(@nospecialize(x)) = W(@lookup(x))                                                    # (c)
gc2(@nospecialize(x)) = w(@lookup(x))                                                   # (c')

const XS = Any[SA("a", [1.0, 2.0]), SB(1, [3.0, 4.0]), SC([5.0, 6.0]), SD(1, 2, [7.0, 8.0])]
loop(f::F, xs) where {F} = (s = 0.0; for x in xs; s += f(x)::Float64; end; s)
for f in (gb, gc, gc2, pl); loop(f, XS); end
@assert loop(gb, XS) == loop(gc, XS) == loop(gc2, XS) == loop(pl, XS)
ns(t) = round(1e9 * t / length(XS); digits = 1)
for (name, f) in (("(b) dispatch, folded view", gb), ("(c) table, offset view, pointer", gc),
                  ("(c') table, offset view, direct", gc2), ("plain dynamic dispatch", pl))
    println(Base.Compiler.NativeInterpreter().facts ? "all  " : "plain  ", rpad(name, 34), ns(@belapsed loop($f, $XS)), " ns/call,  ", (loop(f, XS); @allocated(loop(f, XS))), " bytes per 4 calls")
end
