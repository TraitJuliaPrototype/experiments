# U1 sample 3: MakieCompat (TraitMakie/compat/MakieCompat, TraitMakie c0d5c36) and the old-API code it serves
# (upstream Makie 0.24.16's band.jl and stairs.jl, included unchanged in MakieCompat; TraitMakie's old-API layer,
# TraitMakie/src/TraitMakie.jl). Functions over data vectors (`AbstractVector`, or untyped where the data is
# a vector). Bodies unchanged except: each data argument's annotation is a placeholder for the bound
# (TraitMakie's core traits: `Positions` for points, `Sample` for numbers, `ColorSpec` for per-point colours);
# a `map!` closure of a recipe's `plot!` is a named function of the closure's arguments; a method's point type
# parameter `T <: Point2` is the bound's item type, `Point2d`, written out; a function's own name has the
# prefix `u_`. Placeholders: __SAMPLE__, __POS__, __COLOR__.
#
# A line `## <id> | <function> | <source> | <original signature>` registers a sample.

## M01 | u_pointbased_xy | MakieCompat/src/MakieCompat.jl:441 | _pointbased(xs::AbstractVector{<:Real}, ys::AbstractVector{<:Real})
u_pointbased_xy(xs::__SAMPLE__, ys::__SAMPLE__) = (Point2d[Point2d(x, y) for (x, y) in zip(xs, ys)],)

## M02 | u_pointbased_ps | MakieCompat/src/MakieCompat.jl:442 | _pointbased(ps::AbstractVector{<:Point2})
u_pointbased_ps(ps::__POS__) = (Point2d[Point2d(p[1], p[2]) for p in ps],)

## M03 | u_runs | MakieCompat/src/MakieCompat.jl:489 | _runs(ps)
function u_runs(ps::__POS__)
    out = UnitRange{Int}[]
    start = 0
    for (i, q) in enumerate(ps)
        if _isnanpoint(q)
            start > 0 && push!(out, start:i-1)
            start = 0
        elseif start == 0
            start = i
        end
    end
    start > 0 && push!(out, start:length(ps))
    return out
end

## M04 | u_points | MakieCompat/src/MakieCompat.jl:503 | _points(ps, r)
u_points(ps::__POS__, r) = Point2d[Point2d(ps[i][1], ps[i][2]) for i in r]

## M05 | u_matrix | MakieCompat/src/MakieCompat.jl:627 | _matrix(ps::AbstractVector)
u_matrix(ps::__POS__) = Float64[ps[i][j] for i in eachindex(ps), j in 1:2]

## M06 | u_floats | MakieCompat/src/MakieCompat.jl:628 | _floats(v::AbstractVector{<:Real})
u_floats(v::__SAMPLE__) = Vector{Float64}(v)

## M07 | u_extrema_nan | MakieCompat/src/MakieCompat.jl:71 | extrema_nan(itr)
function u_extrema_nan(itr::__SAMPLE__)
    lo = hi = NaN
    for v in itr
        isfinite(v) || continue
        lo, hi = isnan(lo) ? (v, v) : (min(lo, v), max(hi, v))
    end
    return (lo, hi)
end

## M08 | u_one | MakieCompat/src/MakieCompat.jl:524 | _one(x::AbstractVector, i)
u_one(x::__COLOR__, i) = x[i]

## M09 | u_crange | TraitMakie/src/TraitMakie.jl:55 | _crange(c, ::Nothing)
function u_crange(c::__SAMPLE__, ::Nothing)
    lo, hi = Inf, -Inf
    for v in c
        isfinite(v) || continue
        lo = min(lo, Float64(v)); hi = max(hi, Float64(v))
    end
    isfinite(lo) || return (0.0, 1.0)
    return lo < hi ? (lo, hi) : (lo - 0.5, hi + 0.5)
end

## M10 | u_xy | TraitMakie/src/TraitMakie.jl:74 | _xy(x::AbstractVector, y::AbstractVector)
u_xy(x::__SAMPLE__, y::__SAMPLE__) =
    length(x) == length(y) ? hcat(Vector{Float64}(x), Vector{Float64}(y)) :
    throw(DimensionMismatch("x has $(length(x)) values, y has $(length(y))"))

## M11 | u_gap | TraitMakie/src/TraitMakie.jl:111 | _gap(x)
u_gap(x::__SAMPLE__) = length(x) < 2 ? 1.0 : 0.8 * minimum(diff(sort(Vector{Float64}(x))))

## M12 | u_sample | TraitMakie/src/TraitMakie.jl:78 | _sample(x::AbstractVector{<:Real})
u_sample(x::__SAMPLE__) = Vector{Float64}(x)

## M13 | u_band_convert | MakieCompat/src/upstream/band.jl:23 | convert_arguments(::Type{<:Band}, x, ylower, yupper)
function u_band_convert(x::__SAMPLE__, ylower::__SAMPLE__, yupper::__SAMPLE__)
    return (Point2{float_type(x, ylower)}.(x, ylower), Point2{float_type(x, yupper)}.(x, yupper))
end

## M14 | u_fill_view | MakieCompat/src/upstream/band.jl:114 | fill_view(x, y1, y2, bools::AbstractVector{<:Union{Integer, Bool}})
function u_fill_view(x::__SAMPLE__, y1::__SAMPLE__, y2::__SAMPLE__, bools::AbstractVector{<:Union{Integer, Bool}})
    return view(x, bools), view(y1, bools), view(y2, bools)
end

## M15 | u_band_coords | MakieCompat/src/upstream/band.jl:39 | the `:coordinates` closure of plot!(plot::Band): (lowerpoints, upperpoints, direction)
function u_band_coords(lowerpoints::__POS__, upperpoints::__POS__, direction)
    n = length(lowerpoints)
    @assert n == length(upperpoints) "length of lower band is not equal to length of upper band!"
    concat = [lowerpoints; upperpoints]
    direction in (:x, :y) || error("Invalid band direction $(repr(direction)). Allowed values are :x and :y.")
    if direction === :y && eltype(concat) <: Point2
        concat .= reverse.(concat)
    end
    # if either x, upper or lower is NaN, all of them should be NaN to cut out a whole band segment and not just a triangle
    for i in 1:n
        if isnan(lowerpoints[i]) || isnan(upperpoints[i])
            concat[i] = _nanpoint(eltype(concat))
            concat[n + i] = _nanpoint(eltype(concat))
        end
    end
    return concat
end

## M16 | u_band_merged | MakieCompat/src/upstream/band.jl:94 | the `:merged_points` closure of plot!(plot::Band): (lower, upper, direction)
function u_band_merged(lower::__POS__, upper::__POS__, direction)
    ps = copy(lower)
    push!(ps, eltype(ps)(NaN))
    append!(ps, upper)
    if direction === :y
        ps .= reverse.(ps)
    end
    return ps
end

## M17 | u_steppoints | MakieCompat/src/upstream/stairs.jl:22 | the `:steppoints` closure of plot!(p::Stairs{<:Tuple{<:AbstractVector{T}}}) where {T <: Point2}: (points, step)
function u_steppoints(points::__POS__, step)
    T = Point2d
    isempty(points) && return points
    if step === :pre
        s_points = Vector{T}(undef, length(points) * 2 - 1)
        s_points[1] = point = points[1]
        for i in 1:(length(points) - 1)
            nextpoint = points[i + 1]
            s_points[2i] = T(point[1], nextpoint[2])
            s_points[2i + 1] = nextpoint
            point = nextpoint
        end
        s_points
    elseif step === :post
        s_points = Vector{T}(undef, length(points) * 2 - 1)
        s_points[1] = point = points[1]
        for i in 1:(length(points) - 1)
            nextpoint = points[i + 1]
            s_points[2i] = T(nextpoint[1], point[2])
            s_points[2i + 1] = nextpoint
            point = nextpoint
        end
        s_points
    elseif step === :center
        s_points = Vector{T}(undef, length(points) * 2)
        s_points[1] = point = points[1]
        for i in 1:(length(points) - 1)
            nextpoint = points[i + 1]
            halfx = (point[1] + nextpoint[1]) / 2
            s_points[2i] = T(halfx, point[2])
            s_points[2i + 1] = T(halfx, nextpoint[2])
            point = nextpoint
        end
        s_points[end] = point
        s_points
    else
        error("Invalid step $step. Valid options are :pre, :post and :center")
    end
end
