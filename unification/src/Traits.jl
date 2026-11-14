module Traits

# A stub of the trait library on the unified build, enough for the gates of the
# stages W-98 and W-99: sets and memberships only (writeup/reference/compiler.md §4,
# lowering.md §2–§3). The library itself is W-106.

export @trait, @implement, isopen, declare_membership

# the casts (compiler §6.9): their names are bound, not reserved; a module that uses them imports them
import Core: compiled_for, with_dynamic
export compiled_for, with_dynamic

## Runtime hooks (src/datatype.c)

# open a set: before its binding is published (compiler §4.1)
_open_set!(@nospecialize(T)) = ccall(:jl_set_open_set, Cvoid, (Any,), T)

# is this set open? (the TypeName's bit)
function isopen(@nospecialize(T))::Bool
    dt = Base.unwrap_unionall(T)
    dt isa DataType || return false
    return ccall(:jl_is_open_set, Cint, (Any,), dt) != 0
end

# the entry point behind @implement (compiler §4.2); the caller follows it with
# Expr(:latestworld), so the declaring code sees its own membership (§4.3)
function declare_membership(@nospecialize(member), @nospecialize(set_instance), mod::Module,
                            @nospecialize(by) = nothing, receiver::Symbol = :self)
    return ccall(:jl_declare_membership, Any, (Any, Any, Any, Any, Any),
                 member, set_instance, mod, by, receiver)
end

## The declaration forms

"""
    @trait X
    @trait X <: A          # A a set
    @trait X{P}
    @trait X{P <: B} <: A{P}

Declare the abstract type `X` as a set, open from its declaration: as
`abstract type` lowers, with the set opened before its binding is published.
"""
macro trait(ex)
    name, params, super = _trait_parts(ex)
    mod = __module__
    pnames = Symbol[p isa Symbol ? p : p.args[1] for p in params]
    tvdefs = Any[p isa Symbol ? :($p = Core.TypeVar($(QuoteNode(p)))) :
                 :($(p.args[1]) = Core.TypeVar($(QuoteNode(p.args[1])), $(p.args[2]))) for p in params]
    open_fn = _open_set!
    t = gensym(:set)                  # not a parameter's name
    q = quote
        Core.declare_global($mod, $(QuoteNode(name)), false)
        $(Expr(:latestworld))
        let $(tvdefs...)
            local $t = Core._abstracttype($mod, $(QuoteNode(name)), Core.svec($(pnames...)))
            $open_fn($t)
            Core._setsuper!($t, $super)
            Core._typebody!(false, $t)
            Core.declare_const($mod, $(QuoteNode(name)), $t)
        end
        $(Expr(:latestworld))
        nothing
    end
    return esc(q)
end

"""
    @implement X S
    @implement X{T} S{T}      # one shared set of parameters
    @implement X S{T}         # the member of every instance of X

Declare `S` (a type, or a pattern with free parameter symbols) a member of the set
`X` in a new world, then continue in that world. Returns the `Core.MembershipEntry`.
"""
macro implement(x, s)
    mod = __module__
    decl = declare_membership
    ps = _param_syms(mod, s)
    if isempty(ps)
        xs = _param_syms(mod, x)
        isempty(xs) ||
            error("@implement: $(first(xs)) is a free parameter in the set expression but not in the member pattern")
        return quote
            local e = ($decl)($(esc(s)), $(esc(x)), $mod)
            $(Expr(:latestworld))
            e
        end
    end
    tvs = Core.TypeVar.(ps)
    tvmap = IdDict{Any,Any}(ps .=> tvs)
    tup = Expr(:tuple, QuoteNode.(tvs)...)
    wrap = _wrap_tvs
    mexpr = :($wrap($(esc(_subst_params(s, tvmap))), $tup))
    xs = _param_syms(mod, x)
    all(p -> p in ps, xs) ||
        error("@implement: $(first(setdiff(xs, ps))) is a free parameter in the set expression but not in the member pattern")
    if isempty(xs)
        iexpr = esc(x)
    elseif length(xs) == length(ps)
        iexpr = :($wrap($(esc(_subst_params(x, tvmap))), $tup))
    else
        error("@implement: every parameter of the member pattern must occur in the set expression, or give the bare set")
    end
    return quote
        local e = ($decl)($mexpr, $iexpr, $mod)
        $(Expr(:latestworld))
        e
    end
end

## Helpers

# free parameter symbols of a declaration side: plain symbols in type-argument
# position that the calling module does not define; names bound by `where` are not free
function _param_syms(mod::Module, ex)
    ps = Symbol[]
    _collect_free!(ps, mod, ex, Set{Symbol}())
    return ps
end

function _collect_free!(ps::Vector{Symbol}, mod::Module, ex, bound::Set{Symbol})
    ex isa Expr || return
    if ex.head === :where
        for v in ex.args[2:end]
            if v isa Symbol
                push!(bound, v)
            elseif Meta.isexpr(v, :braces) || Meta.isexpr(v, :curly)
                for w in v.args
                    w isa Symbol && push!(bound, w::Symbol)
                end
            end
        end
        _collect_free!(ps, mod, ex.args[1], bound)
    elseif ex.head === :curly
        for a in ex.args[2:end]
            if a isa Symbol
                !(a in bound) && !(a in ps) && !isdefined(mod, a) && push!(ps, a)
            else
                _collect_free!(ps, mod, a, bound)
            end
        end
    end
    return
end

# replace the free parameter symbols by their minted variables (QuoteNode: the
# object itself, so pattern and instance share it)
function _subst_params(ex, tvmap::IdDict{Any,Any})
    if ex isa Symbol
        tv = get(tvmap, ex, nothing)
        return tv === nothing ? ex : QuoteNode(tv::Core.TypeVar)
    elseif ex isa Expr && ex.head === :curly
        args = Any[ex.args[1]]
        for a in ex.args[2:end]
            push!(args, _subst_params(a, tvmap))
        end
        return Expr(ex.head, args...)
    elseif ex isa Expr && ex.head === :where
        return Expr(ex.head, _subst_params(ex.args[1], tvmap), ex.args[2:end]...)
    end
    return ex
end

# wrap the evaluated body in UnionAlls over the shared variables, first outermost:
# the same order for pattern and instance
function _wrap_tvs(@nospecialize(body), tvs::Tuple)
    body isa Type || error("@implement: $(body) is not a type")
    for i in lastindex(tvs):-1:1
        body = Base.UnionAll(tvs[i], body)::Type
    end
    return body
end

# `X` | `X{Ps...}` | `X <: A` | `X{Ps...} <: A`  →  (name, params, supertype expression)
function _trait_parts(ex)
    super = :Any
    if Meta.isexpr(ex, :<:)
        super = ex.args[2]
        ex = ex.args[1]
    end
    if ex isa Symbol
        return ex, Any[], super
    elseif Meta.isexpr(ex, :curly) && ex.args[1] isa Symbol
        params = Any[]
        for p in ex.args[2:end]
            p isa Symbol || Meta.isexpr(p, :<:) || error("@trait: bad parameter $p")
            push!(params, p)
        end
        return ex.args[1]::Symbol, params, super
    end
    error("@trait expects `X`, `X <: A`, `X{Ps...}`, or `X{Ps...} <: A`, got $ex")
end

end # module
