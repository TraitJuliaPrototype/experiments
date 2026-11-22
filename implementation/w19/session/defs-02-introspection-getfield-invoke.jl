#= base/essentials.jl =#
function unwrap_unionall(@nospecialize(a))
    @_foldable_meta
    while isa(a,UnionAll)
        a = getfield(a, :body)
    end
    return a
end

function isvatuple(@nospecialize(t))
    @_foldable_meta
    t = invoke(unwrap_unionall, Tuple{Any}, t)
    if isa(t, DataType)
        ps = getfield(t, :parameters)
        n = length(ps)
        return n > 0 && isa(ps[n], Core.TypeofVararg)   # `isvarargtype`'s test, on an element of unknown type
    end
    return false
end

function unwrapva(@nospecialize(t))
    isa(t, Core.TypeofVararg) || return t
    return isdefined(t, :T) ? getfield(t, :T) : Any
end

#= base/runtime_internals.jl =#
function datatype_alignment(dt::DataType)
    @_foldable_meta
    layout = getfield(dt, :layout)::Ptr{Cvoid}
    layout == C_NULL && throw(UndefRefError())
    alignment = unsafe_load(convert(Ptr{DataTypeLayout}, layout)).alignment
    return Int(alignment)
end

function datatype_npointers(dt::DataType)
    @_foldable_meta
    layout = getfield(dt, :layout)::Ptr{Cvoid}
    layout == C_NULL && throw(UndefRefError())
    return unsafe_load(convert(Ptr{DataTypeLayout}, layout)).npointers
end

function isabstracttype(@nospecialize(t))
    @_total_meta
    t = invoke(unwrap_unionall, Tuple{Any}, t)
    # TODO: what to do for `Union`?
    return isa(t, DataType) && (getfield(getfield(t, :name), :flags) & 0x1) == 0x1
end

function datatype_fieldcount(t::DataType)
    tn = getfield(t, :name)
    if tn === _NAMEDTUPLE_NAME
        ps = getfield(t, :parameters)
        names, types = ps[1], ps[2]
        if names isa Tuple
            return nfields(names)   # a builtin: `length` at an abstract `Tuple` is a call at an abstract signature
        end
        if types isa DataType && types <: Tuple
            return invoke(datatype_fieldcount, Tuple{DataType}, types)
        end
        return nothing
    elseif invoke(isabstracttype, Tuple{Any}, t)
        return nothing
    end
    if tn === Tuple.name
        invoke(isvatuple, Tuple{Any}, t) && return nothing
        return length(getfield(t, :parameters))   # a tuple type's field types are its parameters
    end
    # Equivalent to length(t.types), but `t.types` is lazy and we do not want
    # to be forced to compute it.
    return length(getfield(tn, :names))
end

function fieldcount(@nospecialize t)
    @_foldable_meta
    if t isa UnionAll || t isa Union
        t = invoke(argument_datatype, Tuple{Any}, t)
        if t === nothing
            throw(ArgumentError("type does not have a definite number of fields"))
        end
    elseif t === Union{}
        throw(ArgumentError("The empty type does not have a well-defined number of fields since it does not have instances."))
    end
    if !(t isa DataType)
        throw(invoke(TypeError, Tuple{Any, Type, Any}, :fieldcount, DataType, t))
    end
    fcount = invoke(datatype_fieldcount, Tuple{DataType}, t)
    if fcount === nothing
        throw(ArgumentError("type does not have a definite number of fields"))
    end
    return fcount
end

function fieldcount_noerror(@nospecialize t)
    if t isa UnionAll || t isa Union
        t = invoke(argument_datatype, Tuple{Any}, t)
        if t === nothing
            return nothing
        end
    elseif t === Union{}
        return 0
    end
    t isa DataType || return nothing
    if t.name === _NAMEDTUPLE_NAME
        names, types = t.parameters
        if names isa Tuple
            return length(names)
        end
        if types isa DataType && types <: Tuple
            return fieldcount_noerror(types)
        end
        return nothing
    elseif isabstracttype(t) || (t.name === Tuple.name && isvatuple(t))
        return nothing
    end
    return isdefined(t, :types) ? length(t.types) : length(t.name.names)
end

