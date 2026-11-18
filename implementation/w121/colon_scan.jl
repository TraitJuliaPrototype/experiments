# E-307: TraitWorld's methods whose inferred code makes a range (Colon) from an argument that is not an Int
using TraitWorld
mods = Set{Module}([TraitWorld, TraitWorld.BaseTraits])
found = Dict{String,Vector{String}}()
Base.visit(Core.methodtable) do m
    m.module in mods || return
    m.sig isa DataType || m.sig isa UnionAll || return
    isdefined(m, :generator) && return
    sig = Base.unwrap_unionall(m.sig)
    tt = Tuple{[p isa TypeVar ? p.ub : p for p in sig.parameters]...}
    local cis
    try
        cis = Base.code_typed_by_type(tt; optimize = false)
    catch
        return
    end
    for (ci, _) in cis
        ci isa Core.CodeInfo || continue
        for (k, st) in enumerate(ci.code)
            Meta.isexpr(st, :call) || continue
            f = st.args[1]
            f isa Core.SSAValue && (f = ci.code[f.id])
            (f isa GlobalRef && f.name === Symbol(":")) || continue
            ts = [a isa Core.SSAValue ? ci.ssavaluetypes[a.id] : a isa Core.Argument ? ci.slottypes[a.n] : a isa Core.SlotNumber ? ci.slottypes[a.id] : typeof(a) for a in st.args[2:end]]
            all(t -> Core.Compiler.widenconst(t) === Int, ts) && continue
            src(a) = a isa Core.SSAValue ? string(ci.code[a.id]) : string(a)
            bounds = join([src(a) for a in st.args[2:end]], " : ")
            bsrc = [a isa Core.SSAValue && Meta.isexpr(ci.code[a.id], :call) ? join([src(x) for x in ci.code[a.id].args], " ") : "" for a in st.args[2:end]]
            line = try string(m.file, ":", ci.debuginfo === nothing ? m.line : Base.IRShow.buildLineInfoNode(ci.debuginfo, nothing, k)[end].line) catch; string(m.file, ":", m.line) end
            push!(get!(found, string(m.name), String[]), string(line, "  (", join(map(t -> string(Core.Compiler.widenconst(t)), ts), ", "), ")  ", bounds, "  <- ", join(bsrc, " | ")))
        end
    end
end
for (k, v) in sort(collect(found)); for l in unique(v); println(rpad(k, 28), l); end; end
