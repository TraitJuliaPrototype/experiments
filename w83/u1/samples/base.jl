# U1 sample 1: Base's abstractarray.jl (julia-1.13), functions over AbstractVector/AbstractArray.
# Each body is Base's, unchanged except: the annotation of each AbstractVector/AbstractArray argument is a
# placeholder for the bound (run.jl substitutes it per variant); Base's internal names are qualified
# (`Base.checked_length`); a function's own name gets the prefix `u_`, its calls keep Base's functions;
# an element type parameter `T` is the bound's fixed item type (Float64), written out.
# Placeholders: __IDX__ read by position, __MIDX__ written by position, __RES__ written and resized,
# __BIDX__ read by position with Bool items, __ITER__ iterated.
#
# A line `## <id> | <function> | <source> | <original signature>` registers a sample.

## B01 | u_first | base/abstractarray.jl:507 | first(v::AbstractVector, n::Integer)
function u_first(v::__IDX__, n::Integer)
    n < 0 && throw(ArgumentError("Number of elements must be non-negative"))
    v[range(begin, length=min(n, Base.checked_length(v)))]
end

## B02 | u_last | base/abstractarray.jl:557 | last(v::AbstractVector, n::Integer)
function u_last(v::__IDX__, n::Integer)
    n < 0 && throw(ArgumentError("Number of elements must be non-negative"))
    v[range(stop=lastindex(v), length=min(n, Base.checked_length(v)))]
end

## B03 | u_copy! | base/abstractarray.jl:924 | copy!(dst::AbstractVector, src::AbstractVector)
function u_copy!(dst::__RES__, src::__IDX__)
    firstindex(dst) == firstindex(src) || throw(ArgumentError(
        "vectors must have the same offset for copy! (consider using `copyto!`)"))
    if length(dst) != length(src)
        resize!(dst, length(src))
    end
    copyto!(dst, src)
end

## B04 | u_copyto_iter! | base/abstractarray.jl:945 | copyto!(dest::AbstractArray, src)
function u_copyto_iter!(dest::__MIDX__, src)
    destiter = eachindex(dest)
    y = iterate(destiter)
    for x in src
        y === nothing &&
            throw(ArgumentError("destination has fewer elements than required"))
        dest[y[1]] = x
        y = iterate(destiter, y[2])
    end
    return dest
end

## B05 | u_copyto_offset! | base/abstractarray.jl:975 | copyto!(dest::AbstractArray, dstart::Integer, src, sstart::Integer)
function u_copyto_offset!(dest::__MIDX__, dstart::Integer, src, sstart::Integer)
    if (sstart < 1)
        throw(ArgumentError(LazyString("source start offset (",sstart,") is < 1")))
    end
    y = iterate(src)
    for j = 1:(sstart-1)
        if y === nothing
            throw(ArgumentError(LazyString(
                "source has fewer elements than required, ",
                "expected at least ", sstart,", got ", j-1)))
        end
        y = iterate(src, y[2])
    end
    if y === nothing
        throw(ArgumentError(LazyString(
            "source has fewer elements than required, ",
            "expected at least ",sstart," got ", sstart-1)))
    end
    i = Int(dstart)
    while y !== nothing
        val, st = y
        dest[i] = val
        i += 1
        y = iterate(src, st)
    end
    return dest
end

## B06 | u_copyto_n! | base/abstractarray.jl:1004 | copyto!(dest::AbstractArray, dstart::Integer, src, sstart::Integer, n::Integer)
function u_copyto_n!(dest::__MIDX__, dstart::Integer, src, sstart::Integer, n::Integer)
    n < 0 && throw(ArgumentError(LazyString("tried to copy n=",n,
        ", elements, but n should be non-negative")))
    n == 0 && return dest
    dmax = dstart + n - 1
    inds = LinearIndices(dest)
    if (dstart ∉ inds || dmax ∉ inds) | (sstart < 1)
        sstart < 1 && throw(ArgumentError(LazyString("source start offset (",
            sstart,") is < 1")))
        throw(BoundsError(dest, dstart:dmax))
    end
    y = iterate(src)
    for j = 1:(sstart-1)
        if y === nothing
            throw(ArgumentError(LazyString(
                "source has fewer elements than required, ",
                "expected at least ",sstart,", got ",j-1)))
        end
        y = iterate(src, y[2])
    end
    if y === nothing
        throw(ArgumentError(LazyString(
            "source has fewer elements than required, ",
            "expected at least ",sstart," got ", sstart-1)))
    end
    val, st = y
    i = Int(dstart)
    @inbounds dest[i] = val
    for val in Iterators.take(Iterators.rest(src, st), n-1)
        i += 1
        @inbounds dest[i] = val
    end
    i < dmax && throw(BoundsError(dest, i))
    return dest
end

## B07 | u_copyto_arr! | base/abstractarray.jl:1073 | copyto!(dest::AbstractArray, src::AbstractArray)
function u_copyto_arr!(dest::__MIDX__, src::__IDX__)
    isempty(src) && return dest
    if dest isa BitArray
        # avoid ambiguities with other copyto!(::AbstractArray, ::SourceArray) methods
        return Base._copyto_bitarray!(dest, src)
    end
    src′ = Base.unalias(dest, src)
    Base.copyto_unaliased!(IndexStyle(dest), dest, IndexStyle(src′), src′)
end

## B08 | u_copy | base/abstractarray.jl:1152 | copy(a::AbstractArray)
function u_copy(a::__IDX__)
    Base.@_propagate_inbounds_meta
    Base.copymutable(a)
end

## B09 | u_copymutable | base/abstractarray.jl:1209 | copymutable(a::AbstractArray)
function u_copymutable(a::__IDX__)
    Base.@_propagate_inbounds_meta
    copyto!(similar(a), a)
end

## B10 | u_zero | base/abstractarray.jl:1215 | zero(x::AbstractArray{T}) where {T<:Number}
u_zero(x::__IDX__) = fill!(similar(x, typeof(zero(Float64))), zero(Float64))

## B11 | u_isempty | base/abstractarray.jl:1259 | isempty(a::AbstractArray)
u_isempty(a::__IDX__) = (length(a) == 0)

## B12 | u_get | base/abstractarray.jl:1622 | get(A::AbstractArray, i::Integer, default)
u_get(A::__IDX__, i::Integer, default) = checkbounds(Bool, A, i) ? A[i] : default

## B13 | u_get! | base/abstractarray.jl:1629 | get!(X::AbstractVector{T}, A::AbstractVector, I::Union{AbstractRange,AbstractVector{Int}}, default::T)
function u_get!(X::__MIDX__, A::__IDX__, I::Union{AbstractRange,AbstractVector{Int}}, default::Float64)
    # 1d is not linear indexing
    ind = findall(in(Base.axes1(A)), I)
    X[ind] = A[I[ind]]
    Xind = Base.axes1(X)
    X[first(Xind):first(ind)-1] = default
    X[last(ind)+1:last(Xind)] = default
    X
end

## B14 | u_isequal | base/abstractarray.jl:3013 | isequal(A::AbstractArray, B::AbstractArray)
function u_isequal(A::__IDX__, B::__IDX__)
    if A === B return true end
    if axes(A) != axes(B)
        return false
    end
    for (a, b) in zip(A, B)
        if !isequal(a, b)
            return false
        end
    end
    return true
end

## B15 | u_cmp | base/abstractarray.jl:3026 | cmp(A::AbstractVector, B::AbstractVector)
function u_cmp(A::__IDX__, B::__IDX__)
    ai1, bi1 = firstindex(A), firstindex(B)
    isequal(ai1, bi1) || return cmp(ai1, bi1)
    for (a, b) in zip(A, B)
        if !isequal(a, b)
            return isless(a, b) ? -1 : 1
        end
    end
    return cmp(length(A), length(B))
end

## B16 | u_isless | base/abstractarray.jl:3052 | isless(A::AbstractVector, B::AbstractVector)
u_isless(A::__IDX__, B::__IDX__) = cmp(A, B) < 0

## B17 | u_eq | base/abstractarray.jl:3054 | ==(A::AbstractArray, B::AbstractArray)
function u_eq(A::__IDX__, B::__IDX__)
    if axes(A) != axes(B)
        return false
    end
    anymissing = false
    for (a, b) in zip(A, B)
        eq = (a == b)
        if ismissing(eq)
            anymissing = true
        elseif !eq
            return false
        end
    end
    return anymissing ? missing : true
end

## B18 | u_map! | base/abstractarray.jl:3387 | map!(f::F, dest::AbstractArray, A::AbstractArray) where F (the parameter F dropped: the trait lowering drops it, a warning)
function u_map!(f, dest::__MIDX__, A::__IDX__)
    for (i,j) in zip(eachindex(dest),eachindex(A))
        val = f(@inbounds A[j])
        @inbounds dest[i] = val
    end
    return dest
end

## B19 | u_map | base/abstractarray.jl:3396 | map(f, A::AbstractArray)
u_map(f, A::__IDX__) = Base.collect_similar(A, Base.Generator(f,A))

## B20 | u_mapany | base/abstractarray.jl:3398 | mapany(f, A::AbstractArray)
u_mapany(f, A::__IDX__) = map!(f, Vector{Any}(undef, length(A)), A)

## B21 | u_push! | base/abstractarray.jl:3554 | push!(a::AbstractVector{T}, item) where T
function u_push!(a::__RES__, item)
    # convert first so we don't grow the array if the assignment won't work
    itemT = item isa Float64 ? item : convert(Float64, item)::Float64
    new_length = length(a) + 1
    resize!(a, new_length)
    a[end] = itemT
    return a
end

## B22 | u_keepat_inds! | base/abstractarray.jl:3604 | _keepat!(a::AbstractVector, inds)
function u_keepat_inds!(a::__RES__, inds)
    local prev
    i = firstindex(a)
    for k in inds
        if @isdefined(prev)
            prev < k || throw(ArgumentError("indices must be unique and sorted"))
        end
        ak = a[k] # must happen even when i==k for bounds checking
        if i != k
            @inbounds a[i] = ak # k > i, so a[i] is inbounds
        end
        prev = k
        i = nextind(a, i)
    end
    deleteat!(a, i:lastindex(a))
    return a
end

## B23 | u_keepat_mask! | base/abstractarray.jl:3622 | _keepat!(a::AbstractVector, m::AbstractVector{Bool})
function u_keepat_mask!(a::__RES__, m::__BIDX__)
    length(m) == length(a) || throw(BoundsError(a, m))
    j = firstindex(a)
    for i in eachindex(a, m)
        @inbounds begin
            if m[i]
                i == j || (a[j] = a[i])
                j = nextind(a, j)
            end
        end
    end
    deleteat!(a, j:lastindex(a))
end

## B24 | u_circshift! | base/abstractarray.jl:3661 | circshift!(a::AbstractVector, shift::Integer)
function u_circshift!(a::__MIDX__, shift::Integer)
    n = length(a)
    n == 0 && return a
    shift = mod(shift, n)
    shift == 0 && return a
    l = lastindex(a)
    reverse!(a, firstindex(a), l-shift)
    reverse!(a, l-shift+1, lastindex(a))
    reverse!(a)
    return a
end

## B25 | u_foreach | base/abstractarray.jl:3212 | foreach(f, itr)
u_foreach(f, itr::__ITER__) = (for x in itr; f(x); end; nothing)
