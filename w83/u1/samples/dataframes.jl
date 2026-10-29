# U1 sample 2: DataFrames' plain API layer in the forks (forks/DataFrames, 943b065), functions over columns
# (`AbstractVector`) and frames (`AbstractDataFrame`). Bodies unchanged except: each column argument's
# annotation is a placeholder for the bound (`Column{T}`, the forks' trait), a frame's for `TableSource`;
# a callable struct's method is a function taking the struct first (`agg_var(agg, …)`); a keyword argument is
# positional (keyword workers are checked per signature, not at archetypes); a function's own name has the
# prefix `u_`; its calls keep DataFrames' functions. Vectors of indices or lengths (`groups`, `lengths`, `p`)
# are not columns and keep their annotations. Placeholders: __COL__ a column read (Float64 cells),
# __COLB__ Bool cells, __COLANY__ cells of any type, __MCOL__ a column written, __TAB__ a frame.
#
# A line `## <id> | <function> | <source> | <original signature>` registers a sample.

## D01 | u_findall | DataFrames/src/other/utils.jl:295 | _findall(B::AbstractVector{Bool})
function u_findall(B::__COLB__)
    @assert firstindex(B) == 1
    nnzB = count(B)

    # fast path returning range
    nnzB == 0 && return 1:0
    len = length(B)
    nnzB == len && return 1:len
    start::Int = findfirst(B)
    nnzB == 1 && return start:start
    start + nnzB - 1 == len && return start:len
    stop::Int = findnext(!, B, start + 1) - 1
    start + nnzB == stop + 1 && return start:stop

    # slow path returning Vector{Int}
    I = Vector{Int}(undef, nnzB)
    @inbounds for i in 1:stop - start + 1
        I[i] = start + i - 1
    end
    cnt = stop - start + 2
    @inbounds for i in stop+1:len
        if B[i]
            I[cnt] = i
            cnt += 1
        end
    end
    @assert cnt == nnzB + 1
    return I
end

## D02 | u_copyto_widen! | DataFrames/src/groupeddataframe/fastaggregates.jl:138 | copyto_widen!(res::AbstractVector{T}, x::AbstractVector) where T
function u_copyto_widen!(res::__MCOL__, x::__COL__)
    @inbounds for i in eachindex(res, x)
        val = x[i]
        S = typeof(val)
        if S <: Float64 || promote_type(S, Float64) <: Float64
            res[i] = val
        else
            newres = Tables.allocatecolumn(promote_type(S, Float64), length(x))
            return copyto_widen!(newres, x)
        end
    end
    return res
end

## D03 | u_groupreduce!_helper | DataFrames/src/groupeddataframe/fastaggregates.jl:152 | groupreduce!_helper(res::AbstractVector, f, op, condf, adjust, checkempty::Bool, incol::AbstractVector, groups::Vector{Int}, counts::Vector{Int}, batches)
function u_groupreduce!_helper(res::__MCOL__, f, op, condf, adjust, checkempty::Bool,
                             incol::__COL__, groups::Vector{Int}, counts::Vector{Int},
                             batches)
    for batch in batches
        # Allow other tasks to do garbage collection while this one runs
        GC.safepoint()

        @inbounds for i in batch
            gix = groups[i]
            x = incol[i]
            if gix > 0 && (condf === nothing || condf(x))
                # this check should be optimized out if U is not Any
                if eltype(res) === Any && !isassigned(res, gix)
                    res[gix] = f(x, gix)
                else
                    res[gix] = op(res[gix], f(x, gix))
                end
                # this check is optimized out by constant propagation
                if adjust !== nothing || checkempty
                    counts[gix] += 1
                end
            end
        end
    end
end

## D04 | u_groupreduce! | DataFrames/src/groupeddataframe/fastaggregates.jl:178 | groupreduce!(res::AbstractVector, f, op, condf, adjust, checkempty::Bool, incol::AbstractVector, gd::GroupedDataFrame)
function u_groupreduce!(res::__MCOL__, f, op, condf, adjust, checkempty::Bool,
                      incol::__COL__, gd::GroupedDataFrame)
    n = length(gd)
    if adjust !== nothing || checkempty
        counts = zeros(Int, n)
    else
        counts = Int[]
    end
    groups = gd.groups
    batchsize = Threads.nthreads() > 1 ? 100_000 : typemax(Int)
    batches = Iterators.partition(eachindex(incol, groups), batchsize)

    groupreduce!_helper(res, f, op, condf, adjust, checkempty,
                             incol, groups, counts, batches)
    # handle the case of an uninitialized reduction
    if eltype(res) === Any
        if op === Base.add_sum
            initf = zero
        elseif op === Base.mul_prod
            initf = one
        else
            initf = x -> throw(ErrorException("Unrecognized op $op"))
        end
        @inbounds for gix in eachindex(res)
            if !isassigned(res, gix)
                res[gix] = initf(nonmissingtype(eltype(incol)))
            end
        end
    end
    if adjust !== nothing
        res .= adjust.(res, counts)
    end
    if checkempty && any(iszero, counts)
        throw(ArgumentError("some groups contain only missing values"))
    end
    # Reallocate Vector created in groupreduce_init with min or max
    # for CategoricalVector
    resT = typeof(res)
    if nameof(resT) === :CategoricalArray && nameof(parentmodule(resT)) === :CategoricalArrays
        @assert op === min || op === max
        # we know that CategoricalArray has `pool` field
        @assert res.pool === incol.pool
        res.pool = copy(incol.pool)
    end
    if isconcretetype(eltype(res))
        return res
    else
        return copyto_widen!(Tables.allocatecolumn(typeof(first(res)), n), res)
    end
end

## D05 | u_agg_var | DataFrames/src/groupeddataframe/fastaggregates.jl:243 | (agg::Aggregate{typeof(var)})(incol::AbstractVector, gd::GroupedDataFrame)
function u_agg_var(agg::Aggregate{typeof(var)}, incol::__COL__, gd::GroupedDataFrame)
    means = groupreduce((x, i) -> x, Base.add_sum, agg.condf, /, false, incol, gd)
    z = zero(eltype(incol)) - zero(eltype(means))
    S = typeof((abs2(z) + abs2(z))/2)
    # !ismissing check is purely an optimization to avoid a copy later
    T = eltype(incol) >: Missing && agg.condf !== !ismissing ?
        T = Union{Missing, S} : S
    res = zeros(T, length(gd))
    return groupreduce!(res, (x, i) -> @inbounds(abs2(x - means[i])), +, agg.condf,
                        (x, l) -> l <= 1 ? x/0 : x/(l-1),
                        false, incol, gd)
end

## D06 | u_agg_std | DataFrames/src/groupeddataframe/fastaggregates.jl:256 | (agg::Aggregate{typeof(std)})(incol::AbstractVector, gd::GroupedDataFrame)
function u_agg_std(agg::Aggregate{typeof(std)}, incol::__COL__, gd::GroupedDataFrame)
    outcol = Aggregate(var, agg.condf)(incol, gd)
    if typeof(sqrt(zero(eltype(outcol)))) === eltype(outcol)
        return map!(sqrt, outcol, outcol)
    else
        return map(sqrt, outcol)
    end
end

## D07 | u_agg_first | DataFrames/src/groupeddataframe/fastaggregates.jl:266 | (agg::Aggregate{typeof(first)})(incol::AbstractVector, gd::GroupedDataFrame)
function u_agg_first(agg::Aggregate{typeof(first)}, incol::__COL__, gd::GroupedDataFrame)
    n = length(gd)
    outcol = similar(incol, n)
    fillfirst!(agg.condf, outcol, incol, gd, rev=agg.f === last)
    if isconcretetype(eltype(outcol))
        return outcol
    else
        return copyto_widen!(Tables.allocatecolumn(typeof(first(outcol)), n), outcol)
    end
end

## D08 | u_fillfirst! | DataFrames/src/groupeddataframe/splitapplycombine.jl:146 | fillfirst!(condf, outcol::AbstractVector, incol::AbstractVector, gd::GroupedDataFrame; rev::Bool=false)
function u_fillfirst!(condf, outcol::__MCOL__, incol::__COL__,
                    gd::GroupedDataFrame, rev::Bool)
    ngroups = gd.ngroups
    # Use group indices if they have already been computed
    idx = getfield(gd, :idx)
    if idx !== nothing && condf === nothing
        v = rev ? gd.ends : gd.starts
        @inbounds for i in 1:ngroups
            outcol[i] = incol[idx[v[i]]]
        end
    elseif idx !== nothing
        nfilled = 0
        starts = gd.starts
        @inbounds for i in eachindex(outcol)
            s = starts[i]
            offsets = rev ? (nrow(gd[i])-1:-1:0) : (0:nrow(gd[i])-1)
            for j in offsets
                x = incol[idx[s+j]]
                if !condf === nothing || condf(x)
                    outcol[i] = x
                    nfilled += 1
                    break
                end
            end
        end
        if nfilled < length(outcol)
            throw(ArgumentError("some groups contain only missing values"))
        end
    else # Finding first row is faster than computing all group indices
        groups = gd.groups
        if rev
            r = length(groups):-1:1
        else
            r = 1:length(groups)
        end
        filled = fill(false, ngroups)
        nfilled = 0
        @inbounds for i in r
            gix = groups[i]
            x = incol[i]
            if gix > 0 && (condf === nothing || condf(x)) && !filled[gix]
                filled[gix] = true
                outcol[gix] = x
                nfilled += 1
                nfilled == ngroups && break
            end
        end
        if nfilled < length(outcol)
            throw(ArgumentError("some groups contain only missing values"))
        end
    end
    return outcol
end

## D09 | u_update_lengths! | DataFrames/src/abstractdataframe/abstractdataframe.jl:2190 | update_lengths!(lengths::Vector{Int}, col::AbstractVector, scalar::Type, df::AbstractDataFrame, col1::Integer, coli::Integer)
function u_update_lengths!(lengths::Vector{Int}, col::__COLANY__, scalar::Type,
                         df::AbstractDataFrame, col1::Integer, coli::Integer)
    for (i, v) in enumerate(col)
        v isa scalar && continue
        lv = length(v)
        if lengths[i] == -1
            lengths[i] = lv
        elseif lengths[i] != lv
            colnames = _names(df)
            throw(ArgumentError("Lengths of iterables stored in columns :$(colnames[col1]) " *
                                "and :$(colnames[coli]) are not the same in row $i"))
        end
    end
end

## D10 | u_repeat_lengths! | DataFrames/src/abstractdataframe/abstractdataframe.jl:2205 | repeat_lengths!(longnew::AbstractVector, shortold::AbstractVector, lengths::AbstractVector{Int})
function u_repeat_lengths!(longnew::__MCOL__, shortold::__COL__,
                         lengths::AbstractVector{Int})
    counter = 1
    @inbounds for i in eachindex(shortold)
        l = lengths[i]
        longnew[counter:(counter + l - 1)] .= Ref(shortold[i])
        counter += l
    end
end

## D11 | u_cycle_permute! | DataFrames/src/abstractdataframe/abstractdataframe.jl:2405 | _cycle_permute!(v::AbstractVector, p::AbstractVector{<:Integer})
function u_cycle_permute!(v::__MCOL__, p::AbstractVector{<:Integer})
    i = firstindex(p)
    @inbounds while i < lastindex(p)
        last_p_i = p[i]
        start = v[last_p_i]
        while true
            i += 1
            p_i = p[i]
            p_i == 0 && break
            v[last_p_i] = v[p_i]
            last_p_i = p_i
        end
        v[last_p_i] = start
        i += 1
    end
    return v
end

## D12 | u_compose_joined_rcol! | DataFrames/src/join/inplace.jl:184 | compose_joined_rcol!(rcol::AbstractVector, rcol_joined::AbstractVector, right_ixs::Vector{Int})
function u_compose_joined_rcol!(rcol::__COL__,
                              rcol_joined::__MCOL__,
                              right_ixs::Vector{Int})
    @assert length(rcol_joined) == length(right_ixs)
    @inbounds for (i, idx) in enumerate(right_ixs)
        if idx > 0
            rcol_joined[i] = rcol[idx]
        end
    end
    return rcol_joined
end

## D13 | u_similar_outer | DataFrames/src/join/composer.jl:11 | similar_outer(leftcol::AbstractVector, rightcol::AbstractVector, n::Int)
u_similar_outer(leftcol::__COL__, rightcol::__COL__, n::Int) =
    Tables.allocatecolumn(promote_type(eltype(leftcol), eltype(rightcol)), n)

## D14 | u_check_aggregate_first | DataFrames/src/groupeddataframe/fastaggregates.jl:48 | check_aggregate(f::typeof(first), v::AbstractVector)
u_check_aggregate_first(f::typeof(first), v::__COL__) =
    eltype(v) === Any ? f : Aggregate(first)

## D15 | u_df_eq | DataFrames/src/abstractdataframe/abstractdataframe.jl:492 | ==(df1::AbstractDataFrame, df2::AbstractDataFrame)
function u_df_eq(df1::__TAB__, df2::__TAB__)
    size(df1, 2) == size(df2, 2) || return false
    isequal(index(df1), index(df2)) || return false
    eq = true
    for idx in 1:size(df1, 2)
        coleq = df1[!, idx] == df2[!, idx]
        # coleq could be missing
        isequal(coleq, false) && return false
        eq &= coleq
    end
    return eq
end

## D16 | u_df_isequal | DataFrames/src/abstractdataframe/abstractdataframe.jl:505 | isequal(df1::AbstractDataFrame, df2::AbstractDataFrame)
function u_df_isequal(df1::__TAB__, df2::__TAB__)
    size(df1, 2) == size(df2, 2) || return false
    isequal(index(df1), index(df2)) || return false
    for idx in 1:size(df1, 2)
        isequal(df1[!, idx], df2[!, idx]) || return false
    end
    return true
end

## D17 | u_df_isempty | DataFrames/src/abstractdataframe/abstractdataframe.jl:434 | isempty(df::AbstractDataFrame)
u_df_isempty(df::__TAB__) = nrow(df) == 0

## D18 | u_df_size | DataFrames/src/abstractdataframe/abstractdataframe.jl:400 | size(df::AbstractDataFrame)
u_df_size(df::__TAB__) = (nrow(df), ncol(df))

## D19 | u_ncol | DataFrames/src/abstractdataframe/abstractdataframe.jl:427 | ncol(df::AbstractDataFrame)
u_ncol(df::__TAB__) = length(index(df))

## D20 | u_completecases | DataFrames/src/abstractdataframe/abstractdataframe.jl:909 | completecases(df::AbstractDataFrame, col::ColumnIndex)
function u_completecases(df::__TAB__, col::ColumnIndex)
    v = df[!, col]
    if Missing <: eltype(v)
        res = BitVector(undef, size(df, 1))
        res .= .!ismissing.(v)
        return res
    else
        return trues(size(df, 1))
    end
end
