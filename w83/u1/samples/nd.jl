# U1 sample 4: NetworkDynamics' plain code (ndport/pkgs/NetworkDynamics-ports, dfc6663, and the upstream
# release 1.3.0 it started from, pkgs/NetworkDynamics.jl) and the plain graph code under it (Graphs on the
# ports, pkgs/Graphs-p4, 54632125). NetworkDynamics' plain code takes a graph in few places (the graph is read
# once, at construction); the component dynamics in its core loop. Five functions from NetworkDynamics, the rest
# from Graphs' generic functions over `AbstractGraph`, which NetworkDynamics' graph code calls.
# Bodies unchanged except: a graph argument's annotation is a placeholder for the bound (`GraphInterface{V}`,
# the ports' trait, with V = Int written out for `T`); a component dynamics argument's (untyped in the core
# loop) is `VertexDynamics` or `EdgeDynamics`; code inline in a larger function is a function of the values it
# reads; NetworkDynamics' internal helpers that take no graph and no dynamics are stubs (run.jl, `NDStubs`);
# a function's own name has the prefix `u_`. Placeholders: __GRAPH__, __VDYN__, __EDYN__.
#
# A line `## <id> | <function> | <source> | <original signature>` registers a sample.

## N01 | u_ffleaves | NetworkDynamics.jl/src/construction.jl:65 (upstream; the ports' check_feedforward_leaves) | inline in Network(g::AbstractGraph, vertexm, edgem; …): (g, _vertexm, _edgem)
function u_ffleaves(g::__GRAPH__, _vertexm, _edgem)
    errorstring = ""
    ffvertices = findall(hasff, _vertexm)
    nbs = map(ffvertices) do i
        Graphs.all_neighbors(g, i)
    end
    ERRORMSG = "Feed forward vertex models are only allowed as leave nodes (1 neighbor) \
                with single `LoopbackConnection` from satelite to cluster node! In other \
                scenarios can use `ff_to_constraint(vf)` on the vertex model to turn \
                feed forward outputs into algebraic states."
    # test all have one neighbor
    if any(n -> length(n) != 1, nbs)
        throw(ArgumentError(ERRORMSG))
    end

    # test all have loopback from ff vert to cluster
    eidx = findall(is_loopback, _edgem)
    simpleedges = collect(edges(g))[eidx]
    all(zip(ffvertices, only.(nbs))) do (src, dst)
        SimpleEdge(src, dst) ∈ simpleedges
    end || throw(ArgumentError(ERRORMSG))

    # check that all looback edges have origin at leaf node
    for (i, e) in zip(eidx, simpleedges)
        if Graphs.degree(g, e.src) != 1
            throw(ArgumentError("All LoopbackConnection edges must originate from leaf nodes! \
                             Found at least one going from hub to leaf: $(_edgem[i])"))
        end
    end
    nothing
end

## N02 | u_prune_blocks! | NetworkDynamics-ports/src/init_resolution.jl:241 | _prune_blocks!(pruned, g, rules, blocks, targets)
function u_prune_blocks!(pruned, g::__GRAPH__, rules, blocks, targets)
    if isnothing(targets) # keep everything
        pruned .= false
        return blocks
    end

    targetset = Set{Symbol}(targets)
    pruned .= true
    kept_blocks = Vector{Int}[]
    for block in blocks
        stays = any(block) do i
            !isdisjoint(rules[i].outsym, targetset) ||
                any(j -> !pruned[j], Graphs.outneighbors(g, i))
        end
        if stays
            pruned[block] .= false
            push!(kept_blocks, block)
        end
    end
    kept_blocks
end

## N03 | u_index_manager | NetworkDynamics.jl/src/network_structure.jl:32 (upstream) | IndexManager(g, dyn_states, edepth, vdepth, vertexm, edgem; valias, ealias): the lines that read g
function u_index_manager(g::__GRAPH__, vertexm, edgem)
    unique_vnames = unique_mappings(getproperty.(vertexm, :name), 1:nv(g))
    unique_enames = unique_mappings(getproperty.(edgem, :name), 1:ne(g))
    evec = collect(edges(g))
    IMStub{typeof(g)}(g, evec,
                      Vector{UnitRange{Int}}(undef, nv(g)),
                      Vector{UnitRange{Int}}(undef, ne(g)),
                      unique_vnames, unique_enames)
end

## N04 | u_vertex! | NetworkDynamics-ports/src/coreloop.jl:282 | _vertex!(m, fg, batch, i, du, u, o, inbufs, p, t)
function u_vertex!(m::__VDYN__, fg, batch, i, du, u, o, inbufs, p, t)
    ef = _evalf(fg, hasf(m)); eg = _evalg(fg); ff = fftype(m)
    nu = ef || ff != PureFeedForward()                                        # _needs_u
    ni = ef || ff isa Union{PureFeedForward, FeedForward}                     # _needs_in
    np = !iszero(pdim(m)) && (ef || ff != PureStateMap())                     # _needs_p
    @inbounds begin
        aggbuf, extbuf = inbufs
        _o   = eg ? view(o, out_range(batch, i))            : nothing
        _du  = ef ? view(du, state_range(batch, i))         : nothing
        _u   = nu ? view(u, state_range(batch, i))          : nothing
        _ins = ni ? (view(aggbuf, in_range(batch, i)),)     : nothing
        _p   = np ? view(p, parameter_range(batch, i))      : nothing
        if !iszero(extdim(m)) && ni
            _ins = (_ins..., view(extbuf, extbuf_range(batch, i)))
        end
        ef && vertexf!(m, _du, _u, _ins, _p, t)
        eg && vertexg!(m, _o, _u, _ins, _p, t)
    end
    nothing
end

## N05 | u_edge! | NetworkDynamics-ports/src/coreloop.jl:303 | _edge!(m, fg, batch, i, du, u, o, inbufs, p, t)
function u_edge!(m::__EDYN__, fg, batch, i, du, u, o, inbufs, p, t)
    ef = _evalf(fg, hasf(m)); eg = _evalg(fg); ff = fftype(m)
    nu = ef || ff != PureFeedForward()                                        # _needs_u
    ni = ef || ff isa Union{PureFeedForward, FeedForward}                     # _needs_in
    np = !iszero(pdim(m)) && (ef || ff != PureStateMap())                     # _needs_p
    @inbounds begin
        gbuf, extbuf = inbufs
        _osrc = eg ? view(o, out_range(batch, i, :src))     : nothing
        _odst = eg ? view(o, out_range(batch, i, :dst))     : nothing
        _du   = ef ? view(du, state_range(batch, i))        : nothing
        _u    = nu ? view(u, state_range(batch, i))         : nothing
        _ins  = ni ? get_src_dst(gbuf, batch, i)            : nothing
        _p    = np ? view(p, parameter_range(batch, i))     : nothing
        if !iszero(extdim(m)) && ni
            _ins = (_ins..., view(extbuf, extbuf_range(batch, i)))
        end
        ef && edgef!(m, _du, _u, _ins, _p, t)
        eg && edgeg!(m, _osrc, _odst, _u, _ins, _p, t)
    end
    nothing
end

## N06 | u_degree | Graphs-p4/src/core.jl:158 | degree(g::AbstractGraph, v::Integer)
function u_degree(g::__GRAPH__, v::Integer)
    if !is_directed(g)
        return outdegree(g, v)
    end
    return indegree(g, v) + outdegree(g, v)
end

## N07 | u_degree_histogram | Graphs-p4/src/core.jl:233 | degree_histogram(g::AbstractGraph{T}, degfn=degree) where {T}
function u_degree_histogram(g::__GRAPH__, degfn=degree)
    hist = Dict{Int,Int}()
    for v in vertices(g)        # minimize allocations by
        for d in degfn(g, v)    # iterating over vertices
            hist[d] = get(hist, d, 0) + 1
        end
    end
    return hist
end

## N08 | u_has_self_loops | Graphs-p4/src/core.jl:385 | has_self_loops(g::AbstractGraph)
function u_has_self_loops(g::__GRAPH__)
    return nv(g) == 0 ? false : any(v -> has_edge(g, v, v), vertices(g))
end

## N09 | u_num_self_loops | Graphs-p4/src/core.jl:411 | num_self_loops(g::AbstractGraph)
u_num_self_loops(g::__GRAPH__) = nv(g) == 0 ? 0 : sum(v -> has_edge(g, v, v), vertices(g))

## N10 | u_noallocextreme | Graphs-p4/src/core.jl:213 | noallocextreme(f, comparison, initial, g)
function u_noallocextreme(f, comparison, initial, g::__GRAPH__)
    value = initial
    for i in vertices(g)
        funci = f(g, i)
        if comparison(funci, value)
            value = funci
        end
    end
    return value
end

## N11 | u_is_connected | Graphs-p4/src/connectivity.jl:143 | is_connected(g::AbstractGraph{T}) where {T}
function u_is_connected(g::__GRAPH__)
    mult = is_directed(g) ? 2 : 1
    if mult * ne(g) + 1 >= nv(g)
        label = zeros(Int, nv(g))
        connected_components!(label, g)
        return allequal(label)
    else
        return false
    end
end

## N12 | u_common_neighbors | Graphs-p4/src/core.jl:359 | common_neighbors(g::AbstractGraph, u::Integer, v::Integer)
function u_common_neighbors(g::__GRAPH__, u::Integer, v::Integer)
    return intersect(neighbors(g, u), neighbors(g, v))
end
