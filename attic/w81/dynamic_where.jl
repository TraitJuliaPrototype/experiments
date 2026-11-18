# W-82 (open issue 84): `c::Dynamic{X{T}} where {T}`: a Dynamic bound whose parameter a `where` variable fixes (traits §5.1)
using TraitWorld
@trait_module module D84
using TraitWorld
export Col, cellat, firstcell, keep
@trait Col{T} begin
    T = eltype(Self)
    cellat(c::Col{T}, i::Int)::T
end
@implement Col A where {A <: AbstractVector} begin
    cellat(c, i) = c[i]
end
firstcell(c::Dynamic{Col{T}}) where {T} = (x = cellat(c, 1); (x, T))
keep(c::Dynamic{Col{T}}) where {T} = Dynamic{Col}(c)
end
using .D84
println("W ", firstcell([1, 2]), " ", firstcell([1.5]), " ", firstcell(["a"]))
println("W ", typeof(keep([1, 2])))
