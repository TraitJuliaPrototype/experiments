# Open issue 251: the bounded check's verdict under candidate readings of a method at the box. Included after
# `using TraitWorld`; defines the module `Readings`. The reading in force is the library's `check_at_box` (R0). Each
# candidate is the same reading with one change (a)-(e), or several:
#   (a) `inferred`  the instance before optimization (inferred, not optimized), callees read the same way;
#   (b) `follow`    a call that passes a value at the box into a callee that is not checked itself (no argument at a
#                   trait, not a trait's own method, not a method of the kept forms, not a forwarder) is followed into
#                   the callee's code at the call's types, as the reading in force follows a call that only throws;
#   (c) `assert`    a builtin call with a value at the box that only throws (`Core.typeassert(t, M)` that always fails
#                   at the box, `getfield` of a field the box does not have) is a fault, as a call is;
#   (d) `errpath`   a call that only throws is a fault only where it reaches a call that finds no method, or reads or
#                   writes a field the trait does not declare;
#   (f) `captured`  (beside the issue's list, with (b)) a value that holds a box or a value known only by its trait in a
#                   field (a closure that captures it, a struct made from it) passes it on, and is followed;
#   (e) `traitbox`  a value known only by its trait (its type a trait instance) is looked up, and followed, at its
#                   box: the call a member that joins later makes.
# `x0` is the reimplementation with no change, a control: its verdicts must be R0's.
module Readings
using TraitWorld
const TW = TraitWorld
const CC = TW.CC
const Dynamic = TraitWorld.Dynamic
const Compiled = TraitWorld.Compiled

struct Fault
    kind::Symbol      # :nomethod, :throws, :field, :assert
    what::String
    line::Int
end
Base.show(io::IO, f::Fault) = print(io, f.kind, ": ", f.what, ", at line ", f.line)

Base.@kwdef struct Opts
    inferred::Bool = false
    follow::Bool = false
    assert::Bool = false
    errpath::Bool = false
    traitbox::Bool = false
    captured::Bool = false
end
const TRACE = Ref(false)
# a walk's result kept per callee signature, its constants and the reading (cost.jl with H_MEMO=1: what a
# check costs where each callee's verdict is kept with the callee's instance and found by a later check; keyed without
# the world: no definition of the corpus changes during cost.jl)
const MEMO = Ref(get(ENV, "H_MEMO", "0") == "1")
const MEMOD = Dict{Any,Any}()
const MEMOSTAT = [0, 0]   # hits, misses
const READINGS = Pair{Symbol,Any}[
    :R0 => nothing,
    :x0 => Opts(),
    :a => Opts(inferred = true),
    :b => Opts(follow = true),
    :c => Opts(assert = true),
    :d => Opts(errpath = true),
    :e => Opts(traitbox = true),
    :cde => Opts(assert = true, errpath = true, traitbox = true),
    :bcde => Opts(follow = true, assert = true, errpath = true, traitbox = true),
    :acde => Opts(inferred = true, assert = true, errpath = true, traitbox = true),
    :all => Opts(inferred = true, follow = true, assert = true, errpath = true, traitbox = true),
    :f => Opts(follow = true, captured = true),
    :allf => Opts(inferred = true, follow = true, assert = true, errpath = true, traitbox = true, captured = true),
]

# ---- helpers -------------------------------------------------------------------------------------------------

const _DYN = Base.unwrap_unionall(Dynamic).name
const _CMP = Base.unwrap_unionall(Compiled).name
function _names_kept_form(@nospecialize(p))
    p isa TypeVar && (p = p.ub)
    Base.isvarargtype(p) && (p = Base.unwrapva(p))
    p isa Union && return any(_names_kept_form, Base.uniontypes(p))
    u = Base.unwrap_unionall(p)
    return u isa DataType && (u.name === _DYN || u.name === _CMP)
end
# a callee the follow (b) does not enter: it is checked itself, or it is the contract's or the kept forms' own code
function _stop_at(m::Method)
    TW._at_box_checked(m) && return true
    TW._is_trait_method(m) && return true
    TW._is_forwarder(m) && return true
    sig = Base.unwrap_unionall(m.sig)
    sig isa DataType || return true
    return any(_names_kept_form, sig.parameters[2:end])
end

# (e): a value known only by its trait, at its box; a tuple element-wise
function _boxed(@nospecialize(T))
    T isa Type || return T
    T isa DataType && T <: Dynamic && return T
    if T isa DataType && T.name === Tuple.name
        ps = Any[]
        for p in T.parameters
            if Base.isvarargtype(p)
                E = _boxed(Base.unwrapva(p))
                push!(ps, isdefined(p, :N) ? Vararg{E, p.N} : Vararg{E})
            else
                push!(ps, _boxed(p))
            end
        end
        return try Tuple{ps...} catch; T end
    end
    X = TW._trait_of(T)
    X === nothing && return T
    Xc = TW._close_params(X)
    Xc === nothing && return T
    return try Dynamic{Xc} catch; T end
end

_argtype(src, @nospecialize(a)) = TW._argtype(src, a)
# (f): a concrete value whose fields hold a value at the box, at any depth up to 4 (a closure's captures, a struct made
# from it, an iterator that holds such a closure)
function _holds_box(@nospecialize(T), depth::Int = 4)
    (depth > 0 && T isa DataType && isconcretetype(T) && !(T <: Dynamic) && T.name !== Tuple.name && !(T <: Type)) || return false
    for F in fieldtypes(T)
        F isa Type || continue
        (F isa DataType && F <: Dynamic || TW._trait_of(F) !== nothing) && return true
        _holds_box(F, depth - 1) && return true
    end
    return false
end
_atbox(@nospecialize(T), opt::Opts) = TW._at_box_value(T) || (opt.captured && _holds_box(T))
# a call's arguments, with `Core._apply_iterate(iterate, f, a, b…)` read as the call of `f` with the tuples spread;
# `nothing` where the spread cannot be read
function _call_parts(src, st::Expr)
    args = st.head === :invoke ? st.args[2:end] : st.args
    fv = TW._callee_value(src, args[1])
    if fv === Core._apply_iterate && length(args) >= 3
        f = args[3]
        ats = Any[]
        for a in args[4:end]
            T = _argtype(src, a)
            (T isa DataType && T.name === Tuple.name) || return nothing
            append!(ats, T.parameters)
        end
        return (f, TW._callee_value(src, f), ats, args[3:end], true)
    end
    return (args[1], fv, Any[_argtype(src, a) for a in args[2:end]], args, false)
end
function _tt(src, @nospecialize(f), ats)
    try
        return Tuple{_argtype(src, f), ats...}
    catch
        return nothing
    end
end
# a call inference proves cannot throw reaches no call that finds no method: not followed (b). The flag is inference's
# own, on the statement, at the call's argument types and constants
# Where the statement invokes a compiled instance, the instance's inferred exception type says the same: a call that
# finds no method throws `MethodError`, an undeclared field read at the box `ArgumentError`; a callee whose exception
# type admits neither is not followed
function _nothrow(src::Core.CodeInfo, i::Int)
    src.ssaflags isa Vector && (src.ssaflags[i] & CC.IR_FLAG_NOTHROW) != 0 && return true
    st = src.code[i]
    st isa Expr && st.head === :(=) && (st = st.args[2])
    if st isa Expr && st.head === :invoke && st.args[1] isa Core.CodeInstance
        E = st.args[1].exctype
        return E isa Type && typeintersect(E, Union{MethodError, ArgumentError}) === Union{}
    end
    return false
end
_has(@nospecialize(tt), world) = tt === nothing ? true : TW._has_method_at(tt, world)
_callstr(src, @nospecialize(fv), args, spread::Bool) = spread ? string(TW._fname(fv, args[1]), "(…)") : TW._callstr(src, fv, args)

function _isfield(@nospecialize(fv), args, ats)
    (fv === getproperty || fv === setproperty!) && length(args) >= 3 && args[3] isa QuoteNode && !isempty(ats) &&
        ats[1] isa DataType && ats[1] <: Dynamic
end

# an argument as inference knows it at the call: a constant where it is one (a literal, a constant global, an SSA
# value inference gives as `Const`), else its type
function _given(src, @nospecialize(a))
    a isa Core.SSAValue && return src.ssavaluetypes[a.id]
    a isa Core.Argument && return src.slottypes[a.n]
    a isa Core.SlotNumber && return src.slottypes[a.id]
    a isa GlobalRef && return isdefined(a.mod, a.name) && isconst(a.mod, a.name) ? Core.Const(getglobal(a.mod, a.name)) : Any
    a isa QuoteNode && return Core.Const(a.value)
    a isa Expr && return Any
    return Core.Const(a)
end
_constval(src, @nospecialize(a)) = (g = _given(src, a); g isa Core.Const ? g.val : TW._callee_value(src, a))
# the call's arguments as inference knows them, a value known only by its trait at its box under (e); nothing for a
# spread call
function _given_call(src, args, spread::Bool, opt::Opts)
    (spread || opt === Opts()) && return nothing
    g = Any[_given(src, a) for a in args]
    if opt.traitbox
        for i = 2:length(g)
            g[i] isa Core.Const && continue
            T = CC.widenconst(g[i])
            TW._at_box_value(T) && (g[i] = _boxed(T))
        end
    end
    return g
end
_hasconst(given) = given !== nothing && any(x -> x isa Core.Const || x isa CC.PartialStruct, given[2:end])

# the callee's code at the call's argument types with the constants the call passes (constant propagation, as the
# call's own inference did), or nothing
function _constprop_code(interp, match::Core.MethodMatch, given::Vector{Any}, optimize::Bool)
    mi = CC.specialize_method(match)
    L = CC.typeinf_lattice(interp)
    cache = CC.matching_cache_argtypes(L, mi)
    argtypes = CC.matching_cache_argtypes(L, mi, CC.SimpleArgtypes(copy(given)), cache)
    argtypes = CC.get_nospecializeinfer_argtypes(argtypes, cache, mi.def::Method)
    ov = falses(length(argtypes))
    for i = 1:length(argtypes)
        argtypes[i] !== CC.argtype_by_index(cache, i) && (ov[i] = true)
    end
    any(ov) || return nothing
    res = CC.InferenceResult(mi, argtypes, ov)
    frame = Base.invoke_in_typeinf_world(CC.InferenceState, res, :no, interp)
    frame === nothing && return nothing
    Base.invoke_in_typeinf_world(CC.typeinf, interp, frame)
    CC.is_inferred(frame) || return nothing
    optimize || return frame.src
    o = Base.invoke_in_typeinf_world(CC.OptimizationState, frame, interp)
    Base.invoke_in_typeinf_world(CC.optimize, interp, o, res)
    return Base.invoke_in_typeinf_world(CC.ir_to_codeinf!, o, frame, Core.svec(o.inlining.edges...))
end

# the code of each method a call at `tt` runs, read at `tt` (with the call's constants, `given`, outside the
# reading in force): (method, CodeInfo) pairs, or nothing
function _codes(interp, @nospecialize(tt), opt::Opts, given = nothing)
    matches = try Base.invoke_interp_compiler(interp, :_findall_matches, interp, tt) catch; nothing end
    matches === nothing && return nothing
    out = Tuple{Method,Core.CodeInfo}[]
    for match in matches.matches
        match = match::Core.MethodMatch
        code = nothing
        if opt !== Opts() && _hasconst(given)
            code = try _constprop_code(interp, match, given, !opt.inferred) catch; nothing end
        end
        code === nothing && (code = try Base.invoke_interp_compiler(interp, :typeinf_code, interp, match, !opt.inferred) catch; nothing end)
        code isa Core.CodeInfo && push!(out, (match.method, code))
    end
    return out
end

# ---- the walk below a call: the chain of calls down to the one that finds no method (or reads an undeclared field)
# `follow`: whether this level was entered through a call that returns (b), so its callees that are checked themselves
# are not entered
function _reaches(interp, @nospecialize(tt), seen::Set{Any}, opt::Opts, world::UInt; returning::Bool = false, given = nothing)
    tt === nothing && return nothing
    tt isa DataType && (tt = Tuple{Any[TW._fixed_length(p) for p in tt.parameters]...})
    # a callee the code does not know (a global not defined, a value of an abstract type) is not entered
    (opt === Opts() || (tt isa DataType && !isempty(tt.parameters) && (F = tt.parameters[1]; F isa DataType && (isconcretetype(F) || F <: Type)))) || return nothing
    key = _hasconst(given) ? (tt, string(given)) : tt
    key in seen && return nothing
    push!(seen, key)
    if MEMO[]
        mk = (key, opt, returning)      # the world advances between checks here, though no method of the corpus changes
        haskey(MEMOD, mk) && (MEMOSTAT[1] += 1; return (r = MEMOD[mk]; r === nothing ? nothing : copy(r)))
        MEMOSTAT[2] += 1
        r = _reaches_(interp, tt, seen, opt, world, returning, given)
        MEMOD[mk] = r === nothing ? nothing : copy(r)
        return r
    end
    return _reaches_(interp, tt, seen, opt, world, returning, given)
end
function _reaches_(interp, @nospecialize(tt), seen::Set{Any}, opt::Opts, world::UInt, returning::Bool, given)
    TRACE[] && println("      walk ", returning ? "(b) " : "", tt)
    codes = _codes(interp, tt, opt, given)
    codes === nothing && return nothing
    if opt === Opts()
        # the reading in force: one method, its optimized code
        length(codes) == 1 || return nothing
    end
    for (m, src) in codes
        returning && _stop_at(m) && continue
        r = _scan_level(interp, src, seen, opt, world)
        r === nothing || return r
    end
    return nothing
end
function _scan_level(interp, src::Core.CodeInfo, seen, opt::Opts, world)
    plain = opt === Opts()
    for (i, st) in enumerate(src.code)
        st isa Expr && st.head === :(=) && (st = st.args[2])
        st isa Expr && st.head in (:call, :invoke) || continue
        parts = _call_parts(src, st)
        parts === nothing && continue
        f, fv, ats, args, spread = parts
        rt = src.ssavaluetypes[i]
        if fv === Core.throw_methoderror && length(ats) >= 1
            any(TW._at_box_value, ats[2:end]) || continue
            rc = TW._raised_call(src, args)
            opt.traitbox && (rc = _boxed(rc))
            _has(rc, world) && continue
            g = TW._callee_value(src, args[2])
            return Any[string(TW._fname(g, args[2]), "(", join((something(TW._closure_form(T), "::" * TW._tstr(T)) for T in ats[2:end]), ", "), ")"), g]
        end
        isbuiltin = fv isa Core.Builtin || fv isa Core.IntrinsicFunction
        (any(T -> _atbox(T, opt), ats) || (opt.captured && _holds_box(_argtype(src, f)))) || continue
        if isbuiltin
            if opt.assert && rt === Union{} && fv !== throw
                return Any[string(TW._fname(fv, f), "(", join(("::" * TW._tstr(T) for T in ats), ", "), ")"), fv]
            end
            continue
        end
        fv === Base.kwerr && continue
        ats_e = opt.traitbox ? Any[_boxed(T) for T in ats] : ats
        if !plain
            # the call as written finds no method at the types the code knows
            tt_e = _tt(src, f, ats_e)
            # an `invoke` has its method; looked up again only where (e) changed an argument
            (st.head === :invoke && ats_e == ats) || _has(tt_e, world) || return Any[string(TW._fname(fv, f), "(", join(("::" * TW._tstr(T) for T in ats_e), ", "), ")"), fv]
            if opt.errpath && _isfield(fv, args, ats) && rt === Union{}
                return Any[string("the field `", args[3].value, "` of ", TW._box_trait_of(ats[1])), fv]
            end
        end
        if rt === Union{}
            below = _reaches(interp, _tt(src, f, ats_e), seen, opt, world; given = _given_call(src, args, spread, opt))
            below === nothing || return pushfirst!(below, TW._link_name(fv, f))
        elseif opt.follow && !_nothrow(src, i)
            below = _reaches(interp, _tt(src, f, ats_e), seen, opt, world; returning = true, given = _given_call(src, args, spread, opt))
            below === nothing || return pushfirst!(below, TW._link_name(fv, f))
        end
    end
    return nothing
end

# ---- the reading of the method itself --------------------------------------------------------------------------

function source(m::Method, opt::Opts; world::UInt = Base.get_world_counter())
    sig = TW.box_signature(m)
    sig === nothing && return nothing
    interp = CC.NativeInterpreter(world; facts = true)
    if !opt.inferred
        src = TW._box_instance(sig, world)
        src === nothing || return (src, interp)
    end
    r = try Base.code_typed_by_type(sig; interp, optimize = !opt.inferred) catch; return nothing end
    (length(r) == 1 && r[1][1] isa Core.CodeInfo) || return nothing
    return (r[1][1], interp)
end

"The faults of `m` read at the box under `opt`, or `nothing` where it is not read."
function faults(m::Method, opt::Opts; world::UInt = Base.get_world_counter())
    s = source(m, opt; world)
    s === nothing && return nothing
    return faults(m, s[1], s[2], opt, world)
end
# the fault's line and the call's text, computed only where a fault is reported
struct LazyLine; src::Core.CodeInfo; i::Int; m::Method; end
function _line(l::LazyLine)
    frames = TW._frames(l.src, l.i)
    return isempty(frames) ? Int(l.m.line) : frames[1][3]
end
struct LazyCall; src::Core.CodeInfo; fv::Any; args::Any; spread::Bool; end
Base.print(io::IO, c::LazyCall) = print(io, _callstr(c.src, c.fv, c.args, c.spread))
Fault(k::Symbol, w::String, l::LazyLine) = Fault(k, w, _line(l))
function faults(m::Method, src::Core.CodeInfo, interp, opt::Opts, world::UInt)
    out = Fault[]
    for (i, st) in enumerate(src.code)
        st isa Expr && st.head === :(=) && (st = st.args[2])
        st isa Expr && st.head in (:call, :invoke) || continue
        parts = _call_parts(src, st)
        parts === nothing && continue
        f, fv, ats, args, spread = parts
        # the line, and the call as printed, only where a fault is reported
        line = LazyLine(src, i, m)
        rt = src.ssavaluetypes[i]
        if fv === Core.throw_methoderror
            length(ats) >= 2 && any(TW._at_box_value, ats[2:end]) || continue
            rc = TW._raised_call(src, args)
            opt.traitbox && (rc = _boxed(rc))
            _has(rc, world) && continue
            g = TW._callee_value(src, args[2])
            push!(out, Fault(:nomethod, string(TW._callstr(src, g, args[2:end]), " has no method"), line))
            continue
        end
        isbuiltin = fv isa Core.Builtin || fv isa Core.IntrinsicFunction
        if isbuiltin || fv === Base.kwerr
            # under (e) too, an assertion of a value known only by its trait is read at its box (`xy(t)::Circ`)
            never = rt === Union{}
            if !never && opt.traitbox && fv === Core.typeassert && length(args) >= 3 && TW._at_box_value(ats[1])
                M = _constval(src, args[3])
                never = M isa Type && typeintersect(_boxed(ats[1]), M) === Union{}
            end
            if opt.assert && isbuiltin && never && fv !== throw && any(T -> _atbox(T, opt), ats)
                what = fv === Core.typeassert && length(args) >= 3 ?
                    string("`", TW._argstr(src, args[2]), "::", _constval(src, args[3]), "` never holds at the box") :
                    string(TW._callstr(src, fv, args), " only throws")
                push!(out, Fault(:assert, what, line))
            end
            continue
        end
        (any(T -> _atbox(T, opt), ats) || (opt.captured && _holds_box(_argtype(src, f)))) || continue
        ats_e = opt.traitbox ? Any[_boxed(T) for T in ats] : ats
        tt = _tt(src, f, ats)
        tt_e = _tt(src, f, ats_e)
        call = LazyCall(src, fv, args, spread)
        if opt !== Opts() && !(st.head === :invoke && ats_e == ats) && !_has(tt_e, world)
            # the call as written finds no method at the types the code knows (a member that joins later, under (e))
            push!(out, Fault(:nomethod, string(call, " has no method", opt.traitbox && tt_e != tt ? " at the box" : ""), line))
            continue
        end
        if st.head === :invoke || rt === Union{}
            if rt === Union{}
                seen = Set{Any}()
                chain = _reaches(interp, tt_e, seen, opt, world; given = _given_call(src, args, spread, opt))
                if chain === nothing
                    if _isfield(fv, args, ats)
                        push!(out, Fault(:field, string("the field `", args[3].value, "` is no declared field of ", TW._box_trait_of(ats[1])), line))
                    elseif !opt.errpath
                        push!(out, Fault(:throws, string(call, " only throws"), line))
                    end
                else
                    push!(out, Fault(:nomethod, string(call, " reaches ", chain[end-1], ", which has no method",
                                                       length(chain) > 2 ? string(" (through ", TW._chain_names(chain[1:end-2]), ")") : ""), line))
                end
            elseif opt.follow && !_nothrow(src, i)
                chain = _reaches(interp, tt_e, Set{Any}(), opt, world; returning = true, given = _given_call(src, args, spread, opt))
                chain === nothing || push!(out, Fault(:nomethod, string(call, " reaches ", chain[end-1], ", which has no method",
                                                       length(chain) > 2 ? string(" (through ", TW._chain_names(chain[1:end-2]), ")") : ""), line))
            end
            continue
        end
        # a call left to run time (optimized), or any call that returns (inferred): no fault where a method applies
        if !_has(tt_e, world)
            push!(out, Fault(:nomethod, string(call, " has no method"), line))
            continue
        end
        if opt.follow && !_nothrow(src, i)
            chain = _reaches(interp, tt_e, Set{Any}(), opt, world; returning = true, given = _given_call(src, args, spread, opt))
            chain === nothing || push!(out, Fault(:nomethod, string(call, " reaches ", chain[end-1], ", which has no method",
                                                   length(chain) > 2 ? string(" (through ", TW._chain_names(chain[1:end-2]), ")") : ""), line))
        end
    end
    return out
end

"The reading in force: the library's `check_at_box`, its body copied (a probe may replace the library's function to record)."
function r0(m::Method; world::UInt = Base.get_world_counter())
    sig = TW.box_signature(m)
    sig === nothing && return nothing
    interp = CC.NativeInterpreter(world; facts = true)
    src = TW._box_instance(sig, world)
    if src === nothing
        r = try Base.code_typed_by_type(sig; interp, optimize = true) catch; return nothing end
        (length(r) == 1 && r[1][1] isa Core.CodeInfo) || return nothing
        src = r[1][1]
    end
    return TW._box_faults(m, src, interp, world)
end

"Every reading of `m`: a vector of (name, faults or nothing, or an exception's text)."
function all_readings(m::Method; world::UInt = Base.get_world_counter(), readings = READINGS)
    out = Pair{Symbol,Any}[]
    for (k, opt) in readings
        r = try
            opt === nothing ? (fs = r0(m; world); fs === nothing ? nothing :
                               Fault[Fault(u.kind, u.what, u.line) for u in fs]) : faults(m, opt; world)
        catch e
            string("ERROR ", sprint(showerror, e))
        end
        push!(out, k => r)
    end
    return out
end
verdict(r) = r === nothing ? "not read" : r isa String ? "error" : isempty(r) ? "bounded" : "not bounded"

end # module Readings
