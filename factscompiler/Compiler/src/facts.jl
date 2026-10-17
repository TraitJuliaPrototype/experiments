# The facts policy as a mode of the native interpreter (plan 2026-10-17-policy-in-compiler, part (A)),
# ported from TraitWorld/src/facts.jl. With the mode on, a call is inferred, with its edges, only
# at a fact signature; any other call is compiled as a dynamic call, typed `Any`, recording
# nothing. One interpreter, one cache: a dynamic call runs code compiled by the same rules.

"Whether the native interpreter compiles by facts (set after the bootstrap: the compiler's own code stays as inferred)."
const FACTS_MODE = RefValue{Bool}(false)
facts_mode(interp::AbstractInterpreter) = interp isa NativeInterpreter && FACTS_MODE[]

"The most concrete signatures one fact may stand for: Julia's own bound on union splitting."
const MAX_FACT_SPLITS = 4

"""
Whether `T` (a call's argument types) is a fact signature: a dispatch tuple; a tuple whose
tuple-typed arguments have unions of concrete element types (it admits exactly the values of its
splits, as top-level union splitting); or a closure's call at kinds (only its owner adds methods).
"""
is_fact_sig(@nospecialize(T)) = T isa DataType && (isdispatchtuple(T) || fact_splits_ok(T) ||
    (T <: Tuple && length(T.parameters) >= 1 && is_closure_type(T.parameters[1]) && kinds_ok(T.parameters)))

function fact_splits_ok(@nospecialize(T))
    (T isa DataType && T <: Tuple) || return false
    ps = T.parameters
    (isempty(ps) || isvarargtype(ps[end])) && return false
    n = 1
    for p in ps
        k = isdispatchelem(p) ? 1 : tuple_splits(p)
        k == 0 && return false
        n *= k
        n > MAX_FACT_SPLITS && return false
    end
    return true
end
"The number of concrete tuple types `P` admits when its elements are concrete or unions of concrete types; 0 if not such a tuple."
function tuple_splits(@nospecialize(P))
    (P isa DataType && P <: Tuple) || return 0
    ps = P.parameters
    (isempty(ps) || isvarargtype(ps[end])) && return 0
    n = 1
    for q in ps
        if isdispatchelem(q)
            k = 1
        elseif q isa Union
            us = uniontypes(q)
            for u in us
                isdispatchelem(u) || return 0
            end
            k = length(us)
        else
            k = tuple_splits(q)
        end
        k == 0 && return 0
        n *= k
        n > MAX_FACT_SPLITS && return 0
    end
    return n
end

"A closure's type: its instance's name is generated (`#…`), unlike a named function's (`sum`)."
function is_closure_type(@nospecialize(F))
    (F isa DataType && F <: Function) || return false
    s = F.name.singletonname
    p = ccall(:jl_symbol_name, Ptr{UInt8}, (Any,), s)
    return Core.Intrinsics.pointerref(p, 1, 1) === UInt8(0x23)     # '#'
end
function kinds_ok(ps::SimpleVector)
    for p in ps
        (p isa Type && (isdispatchelem(p) || p === DataType || p === UnionAll || p === Union)) || return false
    end
    return true
end

const FACTS_ABSTRACT_SITE = FailedMethodMatch("facts mode: argument types not concrete, dispatched at run time")

"`find_method_matches` under the facts mode: every split must be a fact signature."
function facts_find_method_matches(interp::AbstractInterpreter, argtypes::Vector{Any}, @nospecialize(atype),
                                   max_union_splitting::Int, max_methods::Int)
    𝕃 = typeinf_lattice(interp)
    if is_union_split_eligible(𝕃, argtypes, max_union_splitting)
        for arg_n in switchtupleunion(𝕃, argtypes)
            sig_n = argtypes_to_type(arg_n)
            sig_n === Union{} && continue
            is_fact_sig(sig_n) || return FACTS_ABSTRACT_SITE
        end
        return find_union_split_method_matches(interp, argtypes, max_methods)
    end
    is_fact_sig(atype) || return FACTS_ABSTRACT_SITE
    return find_simple_method_matches(interp, atype, max_methods)
end

"""
Compile-time evaluation under the facts mode: a dynamic call already taints the caller's effects,
so only asserted effects (`@assume_effects`) can make code over a run-time site foldable; folding it
would bake in a dispatch no edge records. Allowed only for Julia's own methods (Base, Core), whose
assertions plain Julia trusts in the same way (lesson 1.2).
"""
function facts_eval_refused(result::MethodCallResult)
    edge = result.edge
    edge isa CodeInstance || return false
    m = get_ci_mi(edge).def
    m isa Method || return false
    m.purity == 0 && return false                 # effects inferred, not asserted
    r = Base.moduleroot(m.module)
    return !(r === Base || r === Core)
end
