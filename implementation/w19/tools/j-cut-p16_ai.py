import sys; sys.path.insert(0,'/tmp/claude-harvest/w19f/tools')
from ed import *
P='Compiler/src/abstractinterpretation.jl'
# the closed build's helpers
cut(P, "# the members a closed build splits an operation's call over", "# The split of an operation's call:")
# operation_split_type without the closed build
sub(P, "function operation_split_type(@nospecialize(atype), closed_rules::Bool)", "function operation_split_type(@nospecialize(atype))")
s=rd(P); i=s.index("        (ccall(:jl_is_open_set, Cint, (Any,), X) != 0 || ccall(:jl_has_contract, Cint, (Any,), X) != 0) || continue\n")
j=s.index("    return nothing\nend\n", i)
s=s[:i]+'''        (ccall(:jl_is_open_set, Cint, (Any,), X) != 0 || ccall(:jl_has_contract, Cint, (Any,), X) != 0) || continue
        cands = ccall(:jl_candidates_of, Any, (Any,), X)::Vector{Any}
        U = Union{}
        n = 0
        for C in cands
            n < MAX_OPERATION_SPLITS || break
            C <: p || continue
            U = Union{U, C}
            n += 1
        end
        n == 0 && return nothing
        return (i, U)
    end
'''+s[j:]
wr(P,s)
# trusted_effects: no closed build
s=rd(P); i=s.index("# The effects of a call whose result is a declared result its members' own code is not checked against")
j=s.index("\n\n", i)
s=s[:i]+'''# The effects of a call whose result is a declared result its members' own code is not checked against:
# `TRUSTED_CALLABLE` or `TRUSTED_OPERATION`
trusted_effects(interp::AbstractInterpreter, bits::UInt8, effects::Effects = Effects()) =
    Effects(effects; trusted = bits)'''+s[j:]
wr(P,s)
sub(P, '''                                  sv::AbsIntState, max_methods::Int;
                                  max_union_splitting::Int = InferenceParams(interp).max_union_splitting,
                                  operation::Bool = true, member_split::Bool = true,
                                  @nospecialize(closed_bound = nothing))''', '''                                  sv::AbsIntState, max_methods::Int;
                                  operation::Bool = true)''')
s=rd(P); i=s.index("    drt = operation ? declared_operation_result(interp, argtypes, atype) : nothing\n")
j=s.index("    if isa(matches, FailedMethodMatch)\n", i)
s=s[:i]+'''    drt = operation ? declared_operation_result(interp, argtypes, atype) : nothing
    if drt !== nothing
        # (trusted: a member's own instance is not checked against the declared result in every world
        # it runs in, a member of a pattern before its first use among them; nothing is trusted where
        # the result is `Any`)
        opeffects = drt === Any ? Effects() : trusted_effects(interp, TRUSTED_OPERATION)
        split = operation_split_type(atype)
        split === nothing && return Future(CallMeta(drt, Any, opeffects, DeclaredResultInfo(drt)))
        # asserted, as the compiler's own results are: inferred while the compiler bootstraps itself,
        # an untyped index made `newargs[i]` a dynamic call whose edges any new integer constructor
        # invalidated, and the compiler with it
        i, U = split::Tuple{Int,Type}
        newargs = copy(argtypes)
        newargs[i] = U
        # each branch knows the value's type, a candidate: a branch served by a method at the set runs
        # that method's instance for the candidate, as Julia compiles it, and the branch's case is the
        # candidate, never the set (which would cover the values past the candidates)
        call = abstract_call_gf_by_type(interp, func, ArgInfo(nothing, newargs), si,
                                        argtypes_to_type(newargs), sv, max_methods;
                                        operation = false)::Future
        # (the declared result in a box: a closure over a type is a closure type of its own per type,
        # compiled in each session for each declared result)
        drtbox = RefValue{Any}(drt)
        return Future{CallMeta}(call, interp, sv) do call, _, _
            CallMeta(drtbox[], Any, opeffects, SplitCallInfo(call.info, drtbox[]))
        end
    end
    matches = find_method_matches(interp, argtypes, atype; max_methods)
'''+s[j:]
wr(P,s)
cut(P, "    # a closed build: a call whose method's static parameter a value known only by its\n", "    (; valid_worlds, applicable) = matches\n")
s=rd(P); i=s.index("    state = CallInferenceState(func, matches)\n"); j=s.index("    inbound = RefValue(true)\n", i)+len("    inbound = RefValue(true)\n")
seg=s[i:j]; print(repr(seg))
s=s[:i]+"    state = CallInferenceState(func, matches)\n"+s[j:]; wr(P,s)
sub(P, "                closed_bound === nothing || widenconst(ignorelimited(this_rt)) <: closed_bound || (inbound[] = false)\n", "")
s=rd(P); i=s.index("            # a closed split whose branches each return the wrapper of a member of `X`"); j=s.index("            state.rettype = from_interprocedural!(", i)
print(repr(s[i:j])); s=s[:i]+s[j:]; wr(P,s)
sub(P, '''        # (a closed build infers the call of a function known only by its signature,
        # : it branches over the signature's members)
        if (!isconcretetype(aftw) || (aftw <: Builtin)) && !(closed_build(interp) && callable_set_type(aftw))''', '''        if !isconcretetype(aftw) || (aftw <: Builtin)''')
sub(P, "        # (in a closed build, a call a later member may resolve: inferred again when the members grow)\n        closed_process(interp) && note_closed_operation!(sv)\n", "")
sub(P, '''        # a closed build: the call branches over the signature's members, as an
        # operation's call does, each branch the call at the member's type, its result asserted to `S`
        if closed_build(interp)
            csplit = closed_callable_split(interp, wft, S, arginfo, si, sv, max_methods)
            csplit === nothing || return csplit
        end
''', "")
s=rd(P); i=s.index("    # a call of a function known only as `Callable`, with no signature (an element of a `Vector{Callable}`):"); j=s.index("    if hasintersect(wft, Builtin)\n", i)
print(repr(s[i:j])); s=s[:i]+s[j:]; wr(P,s)
s=rd(P); i=s.index("# A closed build's call of a function known only as `Callable{A, S}`"); j=s.index("# A `Callable{A, S}`'s call: its result `S` is checked", i)
s=s[:i]+s[j:]; wr(P,s)
