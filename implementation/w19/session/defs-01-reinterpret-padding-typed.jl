#= base/reinterpretarray.jl =#
function iterate(cp::CyclePadding)
    y = iterate(cp.padding)
    y === nothing && return nothing
    y[1]::Padding, (0, y[2])
end

function iterate(cp::CyclePadding, state::Tuple)
    y = iterate(cp.padding, tail(state)...)
    y === nothing && return iterate(cp, (state[1]+cp.total_size,))
    p = y[1]::Padding
    Padding(p.offset+state[1], p.size), (state[1], tail(y)...)
end

@assume_effects :foldable function padding(T::DataType, baseoffset::Int = 0)
    pads = Padding[]
    invoke(padding!, Tuple{Vector{Padding}, DataType, Int}, pads, T, baseoffset)
    return Core.svec(pads...)
end

function padding!(pads::Vector{Padding}, T::DataType, baseoffset::Int)
    last_end::Int = baseoffset
    for i = 1:(invoke(fieldcount, Tuple{Any}, T)::Int)
        offset = baseoffset + Int(ccall(:jl_get_field_offset, Csize_t, (Any, Cint), T, i))
        fT = Core.fieldtype(T, i)::DataType
        invoke(padding!, Tuple{Vector{Padding}, DataType, Int}, pads, fT, offset)
        if offset != last_end
            push!(pads, Padding(offset, offset-last_end))
        end
        last_end = offset + Core.sizeof(fT)
    end
    sT = Core.sizeof(T)
    if 0 < last_end - baseoffset < sT
        push!(pads, Padding(baseoffset + sT, sT - last_end + baseoffset))
    end
    return pads
end

function CyclePadding(T::DataType)
    a, s = invoke(datatype_alignment, Tuple{DataType}, T)::Int, Core.sizeof(T)
    as = s + (a - (s % a)) % a
    pad = invoke(padding, Tuple{DataType, Int}, T, 0)
    if s != as
        pad = Core.svec(pad..., Padding(s, as - s))
    end
    CyclePadding(pad, as)
end

@assume_effects :total function array_subpadding(S, T)
    lcm_size = lcm(Core.sizeof(S)::Int, Core.sizeof(T)::Int)
    s, t = invoke(CyclePadding, Tuple{DataType}, S), invoke(CyclePadding, Tuple{DataType}, T)
    checked_size = 0
    # use of Stateful harms inference and makes this vulnerable to invalidation
    (pad, tstate) = let
        it = iterate(t)
        it === nothing && return true
        it
    end
    (ps, sstate) = let
        it = iterate(s)
        it === nothing && return false
        it
    end
    while checked_size < lcm_size
        while true
            # See if there's corresponding padding in S
            ps.offset > pad.offset && return false
            intersect(ps, pad) == pad && break
            ps, sstate = iterate(s, sstate)
        end
        checked_size = pad.offset + pad.size
        pad, tstate = iterate(t, tstate)
    end
    return true
end

@assume_effects :foldable function packedsize(::Type{T}) where T
    pads = padding(T)
    n = 0
    for p in pads
        n += (p::Padding).size
    end
    return sizeof(T) - n
end

