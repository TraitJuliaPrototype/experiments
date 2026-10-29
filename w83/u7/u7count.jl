# E-255 (U7): counters for negative subtyping answers that inference fixes into code.
# Included into the forked Compiler (setup.sh copies it to Compiler/src and patches the call sites).
#
# A negative fold: `isa_tfunc` or `subtype_tfunc` answering `Const(false)`, `tmeet` of a constant
# answering `Bottom` because the value is not an instance, and a `typeintersect` answering `Union{}` (or
# `hasintersect` answering `false`) for two non-empty types, at the call sites in Compiler's own files.
# Each is recorded with its site in the compiler, the kinds of its two sides, and the code being compiled
# (the MethodInstance, the statement). Folds with an open side are recorded with the types too.
#
# Kinds (a bit mask per side): 0x01 a TraitWorld trait (an abstract type below `TraitWorld.Trait`);
# 0x02 a family's abstract type (read from U7_FAMILIES: an abstract type that some `@implement … where
# {A <: F}` ranges over); 0x04 `TraitWorld.Callable`; 0x08 `Dynamic` (concrete, closed under the unified
# model too: informational only); 0x20 `Kept{X}`/`Compiled{X}` (concrete today; the unified model's storage
# simplification, exploration §5.2, makes each `X` itself: the proxy for the questions that today's code
# asks of a trait's values); 0x10 the kind was found inside a `Tuple`'s parameters, not at the top.

const U7_ON = RefValue{Bool}(false)
const U7_FRAME = RefValue{Any}(nothing)
const U7_TN = IdDict{Any,Any}()          # TypeName => UInt8 kind
const U7_FAMILIES = Any[]                # (module name, type name) as Symbols
const U7_TUPLE_TN = Base.typename(Tuple)
const U7_TYPE_TN = Base.typename(Type)
const U7_ALL = IdDict{Any,Any}()         # (site, kL, kR, ctx, mi, pc) => count
const U7_OPEN = IdDict{Any,Any}()        # (site, kL, kR, ctx, mi, pc, inloop, a, b) => count

function _u7_tn_kind(tn::Core.TypeName)
    k = get(U7_TN, tn, nothing)
    k === nothing || return k::UInt8
    kind = 0x00
    modn = ccall(:jl_module_name, Ref{Symbol}, (Any,), tn.module)
    w = unwrap_unionall(tn.wrapper)
    if w isa DataType
        if modn === :TraitWorld && tn.name === :Dynamic
            kind = 0x08
        elseif modn === :TraitWorld && (tn.name === :Kept || tn.name === :Compiled)
            kind = 0x20
        elseif modn === :TraitWorld && tn.name === :Callable
            kind = 0x04
        elseif isabstracttype(w)
            s = w
            while s isa DataType
                sn = s.name
                if sn.name === :Trait && ccall(:jl_module_name, Ref{Symbol}, (Any,), sn.module) === :TraitWorld
                    kind = 0x01
                    break
                end
                s === Any && break
                s = s.super
            end
            if kind == 0x00
                for f in U7_FAMILIES
                    f = f::Tuple{Symbol,Symbol}
                    if f[1] === modn && f[2] === tn.name
                        kind = 0x02
                        break
                    end
                end
            end
        end
    end
    U7_TN[tn] = kind
    return kind
end

function _u7_kind(@nospecialize(t), intuple::Bool=false)
    t isa UnionAll && (t = unwrap_unionall(t))
    if t isa Union
        return _u7_kind(t.a, intuple) | _u7_kind(t.b, intuple)
    elseif t isa DataType
        tn = t.name
        if tn === U7_TUPLE_TN
            intuple && return 0x00
            k = 0x00
            for p in t.parameters
                p isa Core.TypeofVararg && (p = isdefined(p, :T) ? p.T : Any)
                k |= _u7_kind(p, true)
            end
            return k == 0x00 ? k : (k | 0x10)
        elseif tn === U7_TYPE_TN
            return 0x00
        end
        return _u7_tn_kind(tn)
    end
    return 0x00
end

"Whether statement `pc` lies in a loop: some block at or after its block jumps back to or before it."
function _u7_inloop(blocks::Vector{BasicBlock}, index::Vector{Int}, pc::Int)
    (pc < 1 || isempty(blocks) || pc > last(blocks[end].stmts)) && return false
    bb = min(block_for_inst(index, pc), length(blocks))
    for j = bb:length(blocks)
        for s in blocks[j].succs
            s <= bb && return true
        end
    end
    return false
end

function _u7_neg(site::String, @nospecialize(a), @nospecialize(b))
    U7_ON[] || return nothing
    U7_ON[] = false     # no counting of the counter's own work
    kL = _u7_kind(a)
    kR = _u7_kind(b)
    fr = U7_FRAME[]
    ctx = :none; mi = nothing; pc = 0
    blocks = nothing; index = nothing
    if fr isa InferenceState
        ctx = :inf; mi = fr.linfo; pc = fr.currpc
        blocks = fr.cfg.blocks; index = fr.cfg.index
    elseif fr isa IRInterpretationState
        ctx = :irinterp; mi = fr.mi; pc = fr.curridx
        blocks = fr.ir.cfg.blocks; index = fr.ir.cfg.index
    elseif fr isa OptimizationState
        ctx = :opt; mi = fr.linfo
    end
    key = (site, kL, kR, ctx, mi, pc)
    U7_ALL[key] = (get(U7_ALL, key, 0)::Int) + 1
    if ((kL | kR) & 0x27) != 0x00
        inl = blocks === nothing ? false : _u7_inloop(blocks::Vector{BasicBlock}, index::Vector{Int}, pc)
        okey = (site, kL, kR, ctx, mi, pc, inl, a, b)
        U7_OPEN[okey] = (get(U7_OPEN, okey, 0)::Int) + 1
    end
    U7_ON[] = true
    return nothing
end

"`isa_tfunc`/`subtype_tfunc`: a negative answer, recorded."
function _u7f(site::String, @nospecialize(a), @nospecialize(b))
    _u7_neg(site, a, b)
    return Const(false)
end

function _u7ti(site::String, @nospecialize(a), @nospecialize(b))
    r = typeintersect(a, b)
    if r === Bottom && a !== Bottom && b !== Bottom && U7_ON[]
        _u7_neg(site, a, b)
    end
    return r
end

function _u7hi(site::String, @nospecialize(a), @nospecialize(b))
    r = hasintersect(a, b)
    if !r && a !== Bottom && b !== Bottom && U7_ON[]
        _u7_neg(site, a, b)
    end
    return r
end

# --- control and the report (called from outside the compiler) ------------------------------------

function u7_start!(families::Vector{Tuple{Symbol,Symbol}})
    empty!(U7_FAMILIES); append!(U7_FAMILIES, families)
    empty!(U7_TN)
    U7_ON[] = true
    return nothing
end
u7_stop!() = (U7_ON[] = false; nothing)
