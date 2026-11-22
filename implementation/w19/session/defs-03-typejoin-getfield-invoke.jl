#= base/essentials.jl =#
function rewrap_unionall(@nospecialize(t), @nospecialize(u))
    @_foldable_meta
    if !isa(u, UnionAll)
        return t
    end
    return invoke(UnionAll, Tuple{Any, Any}, getfield(u, :var), invoke(rewrap_unionall, Tuple{Any, Any}, t, getfield(u, :body)))
end

#= base/operators.jl =#
supertype(T::DataType) = (@_total_meta; getfield(T, :super))

#= base/promotion.jl =#
function typejoin(@nospecialize(a), @nospecialize(b))
    @_foldable_meta
    @_nothrow_meta
    @_nospecializeinfer_meta
    if isa(a, TypeVar)
        return invoke(typejoin, Tuple{Any, Any}, getfield(a, :ub), b)
    elseif isa(b, TypeVar)
        return invoke(typejoin, Tuple{Any, Any}, a, getfield(b, :ub))
    elseif a === b
        return a
    elseif !isa(a, Type) || !isa(b, Type)
        return Any
    elseif a <: b
        return b
    elseif b <: a
        return a
    elseif isa(a, UnionAll)
        return invoke(UnionAll, Tuple{Any, Any}, getfield(a, :var), invoke(typejoin, Tuple{Any, Any}, getfield(a, :body), b))
    elseif isa(b, UnionAll)
        return invoke(UnionAll, Tuple{Any, Any}, getfield(b, :var), invoke(typejoin, Tuple{Any, Any}, a, getfield(b, :body)))
    elseif isa(a, Union)
        return invoke(typejoin, Tuple{Any, Any}, invoke(typejoin, Tuple{Any, Any}, getfield(a, :a), getfield(a, :b)), b)
    elseif isa(b, Union)
        return invoke(typejoin, Tuple{Any, Any}, a, invoke(typejoin, Tuple{Any, Any}, getfield(b, :a), getfield(b, :b)))
    end
    # a and b are DataTypes
    # We have to hide Constant info from inference, see #44390
    a, b = compilerbarrier(:type, a)::DataType, compilerbarrier(:type, b)::DataType
    if a <: Tuple
        if !(b <: Tuple)
            return Any
        end
        ap, bp = getfield(a, :parameters), getfield(b, :parameters)
        lar = length(ap)
        lbr = length(bp)
        if lar == 0
            return Tuple{Vararg{tailjoin(bp, 1)}}
        end
        if lbr == 0
            return Tuple{Vararg{tailjoin(ap, 1)}}
        end
        laf, afixed = full_va_len(ap)
        lbf, bfixed = full_va_len(bp)
        if laf < lbf
            if isa(ap[lar], Core.TypeofVararg) && !afixed
                c = Vector{Any}(undef, laf)
                c[laf] = Vararg{invoke(typejoin, Tuple{Any, Any}, invoke(unwrapva, Tuple{Any}, ap[lar]), tailjoin(bp, laf))}
                n = laf-1
            else
                c = Vector{Any}(undef, laf+1)
                c[laf+1] = Vararg{tailjoin(bp, laf+1)}
                n = laf
            end
        elseif lbf < laf
            if isa(bp[lbr], Core.TypeofVararg) && !bfixed
                c = Vector{Any}(undef, lbf)
                c[lbf] = Vararg{invoke(typejoin, Tuple{Any, Any}, invoke(unwrapva, Tuple{Any}, bp[lbr]), tailjoin(ap, lbf))}
                n = lbf-1
            else
                c = Vector{Any}(undef, lbf+1)
                c[lbf+1] = Vararg{tailjoin(ap, lbf+1)}
                n = lbf
            end
        else
            c = Vector{Any}(undef, laf)
            n = laf
        end
        for i = 1:n
            ai = ap[min(i,lar)]; bi = bp[min(i,lbr)]
            ci = invoke(typejoin, Tuple{Any, Any}, invoke(unwrapva, Tuple{Any}, ai), invoke(unwrapva, Tuple{Any}, bi))
            c[i] = i == length(c) && (isa(ai, Core.TypeofVararg) || isa(bi, Core.TypeofVararg)) ? Vararg{ci} : ci
        end
        return Tuple{c...}
    elseif b <: Tuple
        return Any
    end
    while !(b === Any)
        bname = getfield(b, :name)
        if a <: getfield(bname, :wrapper)
            while !(getfield(a, :name) === bname)
                a = getfield(a, :super)::DataType
            end
            if bname === Type.body.name
                ap = getfield(a, :parameters)[1]
                bp = getfield(b, :parameters)[1]
                if ((isa(ap,TypeVar) && getfield(ap, :lb) === Bottom && getfield(ap, :ub) === Any) ||
                    (isa(bp,TypeVar) && getfield(bp, :lb) === Bottom && getfield(bp, :ub) === Any))
                    # handle special Type{T} supertype
                    return Type
                end
            end
            aprimary = getfield(bname, :wrapper)
            # join on parameters
            aps, bps = getfield(a, :parameters), getfield(b, :parameters)
            n = length(aps)
            if n == 0
                return aprimary
            end
            vars = []
            for i = 1:n
                ai, bi = aps[i], bps[i]
                if ai === bi || (isa(ai,Type) && isa(bi,Type) && ai <: bi && bi <: ai)
                    aprimary = aprimary{ai}
                else
                    aprimary = aprimary::UnionAll
                    # pushfirst!(vars, aprimary.var)
                    _growbeg!(vars, 1)
                    vars[1] = getfield(aprimary, :var)
                    aprimary = getfield(aprimary, :body)
                end
            end
            for v in vars
                aprimary = invoke(UnionAll, Tuple{Any, Any}, v, aprimary)
            end
            return aprimary
        end
        b = getfield(b, :super)::DataType
    end
    return Any
end

function typesplit(@nospecialize(a), @nospecialize(b))
    @_foldable_meta
    @_nospecializeinfer_meta
    if a <: b
        return Bottom
    end
    if isa(a, Union)
        return Union{invoke(typesplit, Tuple{Any, Any}, getfield(a, :a), b),
                     invoke(typesplit, Tuple{Any, Any}, getfield(a, :b), b)}
    end
    return a
end

function promote_typejoin(@nospecialize(a), @nospecialize(b))
    c = invoke(typejoin, Tuple{Any, Any}, invoke(_promote_typesubtract, Tuple{Any}, a), invoke(_promote_typesubtract, Tuple{Any}, b))
    return Union{a, b, c}::Type
end

_promote_typesubtract(@nospecialize(a)) =
    a === Any ? a :
    Union{Nothing, Missing} <: a ? invoke(typesplit, Tuple{Any, Any}, a, Union{Nothing, Missing}) :
    Nothing <: a ? invoke(typesplit, Tuple{Any, Any}, a, Nothing) :
    Missing <: a ? invoke(typesplit, Tuple{Any, Any}, a, Missing) :
    a


function full_va_len(p::Core.SimpleVector)
    isempty(p) && return 0, true
    last = p[end]
    if isa(last, Core.TypeofVararg)
        if isdefined(last, :N)
            N = getfield(last, :N)
            isa(N, Int) && return length(p) + N - 1, true
        end
        return length(p), false
    end
    return length(p), true
end

function tailjoin(A::SimpleVector, i::Int)
    @_foldable_meta
    if i > length(A)
        return invoke(unwrapva, Tuple{Any}, A[end])
    end
    t = Bottom
    for j = i:length(A)
        t = invoke(typejoin, Tuple{Any, Any}, t, invoke(unwrapva, Tuple{Any}, A[j]))
    end
    return t
end

