#= base/show.jl =#
function IOContext(io::IO, KV::Pair)
    d = ioproperties(io)
    return IOContext(io, invoke(ImmutableDict{Symbol,Any}, Tuple{ImmutableDict, Any, Any}, d, KV[1], KV[2]))
end

