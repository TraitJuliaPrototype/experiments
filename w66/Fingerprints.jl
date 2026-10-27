# E-195 (W-66): an entry's identity by fingerprints scoped by the facts rule (writeup/plans/2026-10-27-facts-keyed-cache.md
# §5b). For a CodeInstance of owner :facts:
#   F1  its method's signature and lowered code, as this session holds it (macro expansions included);
#   F2  for each fact (each edge: a callee, or a signature resolved by dispatch): the stakeholders' methods of the fact's
#       function (owners of the function and of the types in the signature), with their signatures and lowered code;
#       for a callee CodeInstance, its inferred result;
#   F3  the layouts of the types in its signature, result and inferred code.
# Methods from outside the stakeholders are the candidate index's (E-193); bindings and folds are checked as today.
module Fingerprints

const STABLE = Ref{UInt}(0x5eed)
h(x) = hash(x, STABLE[])

"A package's name for a module, `nothing` for Base and Core."
pkgof(m::Module) = (r = Base.moduleroot(m); r === Base || r === Core ? nothing : string(nameof(r)))

"F1, and a stakeholder's method: its signature and lowered code."
const SRC = IdDict{Method,UInt}()
function method_fp(m::Method)
    get!(SRC, m) do
        # the lowered code, uncompressed and printed with global references by name: the compressed bytes differ
        # between builds of the same source (the roots' order)
        code = try
            ci = Base.uncompressed_ast(m)
            string(ci.code, "|", ci.slotnames)
        catch
            isdefined(m, :generator) ? string(m.generator) : ""
        end
        h((string(m.module), string(m.name), string(m.sig), code))
    end
end

"The stakeholders of a fact at signature `sig`: the owners of its function and of the types in it."
function stakeholders(@nospecialize(sig))
    out = Set{Union{Nothing,String}}([nothing])          # Base and Core: the Julia build, in the key
    walk(@nospecialize(x)) =
        x isa Union ? (walk(x.a); walk(x.b)) :
        x isa UnionAll ? walk(x.body) :
        x isa DataType ? (push!(out, pkgof(x.name.module)); foreach(walk, x.parameters)) : nothing
    walk(sig)
    return out
end

"F2 for a signature: the stakeholders' methods of its function (all of them: an update that adds or changes one changes it)."
const FUNC = Dict{Tuple{Any,Set{Union{Nothing,String}}},UInt}()
function fact_fp(@nospecialize(sig))
    (sig isa DataType && sig <: Tuple && length(sig.parameters) >= 1) || return h(string(sig))
    ft = sig.parameters[1]
    (ft isa DataType && isdefined(ft, :instance)) || return h(string(sig))
    sh = stakeholders(sig)
    get!(FUNC, (ft, sh)) do
        fps = UInt[method_fp(m) for m in methods(ft.instance) if pkgof(m.module) in sh]
        h(sort!(fps))
    end
end

"A callee CodeInstance's inferred result, as its caller's code depends on it."
callee_fp(ci::Core.CodeInstance) = h((string(ci.rettype), string(ci.exctype), ci.ipo_purity_bits,
                                      isdefined(ci, :rettype_const) ? string(ci.rettype_const) : ""))

"F3: a type's layout."
function layout_fp(@nospecialize(T))
    T isa DataType || return h(string(T))
    fl = isconcretetype(T) && !(T <: Type) ? (try (sizeof(T), Base.datatype_alignment(T)) catch; (0, 0) end) : (0, 0)
    # an abstract or variadic type has no definite fields: its name is its layout here
    names = try fieldnames(T) catch; () end
    types = try string.(fieldtypes(T)) catch; String[] end
    return h((string(T), ismutabletype(T), names, types, fl))
end
function types_in!(out, @nospecialize(x))
    x isa DataType ? (push!(out, x); foreach(p -> types_in!(out, p), x.parameters)) :
    x isa Union ? (types_in!(out, x.a); types_in!(out, x.b)) :
    x isa UnionAll ? types_in!(out, x.body) :
    x isa Core.Const ? types_in!(out, typeof(x.val)) : x isa Type ? nothing :
    x isa Core.PartialStruct ? types_in!(out, x.typ) : nothing
    return out
end

mi_of(ci::Core.CodeInstance) = ci.def isa Core.MethodInstance ? ci.def : ci.def.def

"The inferred code of a facts CodeInstance, uncompressed, or nothing."
function inferred(ci::Core.CodeInstance)
    src = ci.inferred
    src isa Core.CodeInfo && return src
    src isa String || return nothing
    m = mi_of(ci).def
    m isa Method || return nothing
    return try ccall(:jl_uncompress_ir, Any, (Any, Any, Any), m, ci, src) catch; nothing end
end

"The entry's fingerprint, and its parts (for diagnosis)."
function entry_fp(ci::Core.CodeInstance)
    mi = mi_of(ci); m = mi.def::Method
    f1 = method_fp(m)
    f2 = UInt[]
    if isdefined(ci, :edges)
        for e in ci.edges
            if e isa Core.CodeInstance
                push!(f2, h((fact_fp(mi_of(e).specTypes), callee_fp(e))))
            elseif e isa Core.MethodInstance
                push!(f2, fact_fp(e.specTypes))
            elseif e isa Type
                push!(f2, fact_fp(e))
            end
        end
    end
    tys = Set{DataType}()
    types_in!(tys, mi.specTypes); types_in!(tys, ci.rettype)
    src = inferred(ci)
    if src !== nothing
        st = src.ssavaluetypes
        st isa Vector && foreach(t -> types_in!(tys, t), st)
        for st in src.code
            st isa GlobalRef && (v = try getglobal(st.mod, st.name) catch; nothing end; v isa DataType && push!(tys, v))
            if st isa Expr
                for a in st.args
                    a isa GlobalRef && (v = try getglobal(a.mod, a.name) catch; nothing end; v isa DataType && push!(tys, v))
                    a isa DataType && push!(tys, a)
                end
            end
        end
    end
    f3 = sort!(UInt[layout_fp(T) for T in tys])
    return h((f1, sort!(f2), f3)), (f1 = f1, f2 = h(sort!(f2)), f3 = h(f3))
end

"The entry's key: its method and specialization, by name."
entry_key(ci::Core.CodeInstance) = (mi = mi_of(ci); string(mi.def.module, ".", mi.def.name, " ", mi.specTypes))

"The entry's compiled code as a witness: the method's code as the compiler types and optimizes it in this session, printed."
function code_witness(ci::Core.CodeInstance)
    mi = mi_of(ci)
    ct = try Base.code_typed_by_type(mi.specTypes; optimize = true) catch; Any[] end
    return h((string(ct), string(ci.rettype)))
end

end
