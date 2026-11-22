#= base/sort.jl =#
function issorted(itr;
        lt::L=isless, by::B=identity, rev::Union{Bool,Nothing}=nothing, order::Ordering=Forward) where {L,B}
    # `lt` and `by` are only passed on: without `L` and `B` the body is compiled at `Function`, where
    # `ord` is not resolved (a trimmed build refuses it).
    # Explicit branching because the compiler can't optimize away the
    # type instability of the `ord` call with Bool `rev` parameter.
    if rev === true
        issorted(itr, ord(lt, by, true, order))
    else
        issorted(itr, ord(lt, by, nothing, order))
    end
end

