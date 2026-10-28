# W-81 (open issue 83): a `Callable` whose argument types follow the other arguments (traits §5.8)
using TraitWorld
@trait_module module G83
using TraitWorld
export count_if, scale_each
# T fixed by a trait bound's parameter
count_if(f::Callable{Tuple{T}, Bool}, xs::Iterable{T}) where {T} = (n = 0; for x in xs; f(x) && (n += 1); end; n)
# T fixed by a plain argument
scale_each(f::Callable{Tuple{T}, T}, v::Vector{T}) where {T} = [f(x) for x in v]
end
using .G83
println("A ", count_if(iseven, [1, 2, 3, 4]), " (2)")
println("A ", count_if(x -> x > 1.5, [1.0, 2.0, 3.0]), " (2)")
println("A ", scale_each(x -> 2x, [1, 2]), " ([2, 4])")
println("A ", scale_each(x -> 2x, [1.5]), " ([3.0])")
# a function whose result is not Bool at T is refused at the call
r = try; count_if(x -> x, [1, 2]); "accepted"; catch e; "refused: " * first(sprint(showerror, e), 150); end
println("A ", r)
# a Callable naming a variable no other argument fixes is refused at the definition
r = try
    Core.eval(G83, :(bad(f::Callable{Tuple{S}, Bool}, x::Int) where {S} = f(x)))
    "accepted"
catch e
    "refused: " * first(sprint(showerror, e), 160)
end
println("A ", r)
# typed callers: one entry per signature, the second call allocation-free
f2(v) = count_if(iseven, v)
f2([1, 2]); println("A allocs ", @allocated(f2([1, 2, 3, 4])))
