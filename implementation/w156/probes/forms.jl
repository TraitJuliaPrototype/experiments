# W-156 probe: at a dynamic call of a method at a trait without a default, which instance runs for a
# plain member, the wrapper (`TraitWorld.ByType.compiled_for`) and Julia's cast (`Core.compiled_for`),
# in a trait module with `first_seen` on (the library's default) and off.
using TraitWorld
import TraitWorld.ByType
for fs in (true, false)
    name = Symbol(:P, fs)
    @eval module $name
    using TraitWorld
    @trait_module first_seen = $fs
    @trait Col{T} begin
        T = eltype(Self)
        nr(c::Col)::Int
        cl(c::Col{T}, i::Int)::T
    end
    @implement Col{T} Vector{T} where {T} begin
        nr(c) = length(c)
        cl(c, i) = c[i]
    end
    seen = Any[]
    function take(c::Col, i::Int)
        push!(seen, typeof(c))
        return cl(c, i)
    end
    run_plain(cols::Vector{Col}) = [take(c, 1) for c in cols]
    run_wrap(cols::Vector{Col}) = [take($(ByType.compiled_for)(c), 1) for c in cols]
    run_cast(cols::Vector{Col}) = [take(compiled_for(c), 1) for c in cols]   # Julia's cast: the library exports it
    end
end
cols(M) = M.Col[[1.0, 2.0], [3, 4], ["a"]]
# the instances of `f` that hold code (a CodeInstance in their cache)
spec(f) = Set([string(mi.specTypes) for m in methods(f) for mi in Base.specializations(m) if mi !== nothing && isdefined(mi, :cache)])
for M in (P1 = @eval(Main.Ptrue), P0 = @eval(Main.Pfalse))
    for r in (:run_plain, :run_wrap, :run_cast)
        empty!(M.seen)
        before = spec(M.take)
        res = getfield(M, r)(cols(M))
        println(nameof(M), " ", r, ": ", res, " | typeof at take: ", unique(M.seen), " | code compiled: ", sort(collect(setdiff(spec(M.take), before))))
    end
end
