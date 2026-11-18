# E-355: which optimized statements carry an argument that is not an IR value (the fatal error of
# `rtsite_target` while JSON's image was built over Parsers compiled by facts)?
#     julia --project=env_facts scan_args.jl Parsers ...
for p in ARGS; Core.eval(Main, Meta.parse("import $p")); end
const mods = Set(Symbol.(ARGS))
seen = Dict{String,Int}(); n = 0
Base.visit(Core.methodtable) do m
    nameof(Base.moduleroot(m.module)) in mods || return
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        r = try Base.code_typed_by_type(mi.specTypes; optimize = true) catch; continue end
        for (src, _) in r
            src isa Core.CodeInfo || continue
            global n += 1
            for stmt in src.code
                Meta.isexpr(stmt, :(=)) && (stmt = stmt.args[2])
                Meta.isexpr(stmt, :call) || continue
                for a in stmt.args
                    a isa Expr || continue
                    k = string(a.head, " in ", stmt.args[1])
                    haskey(seen, k) || println(k, " :: ", stmt, "   in ", mi)
                    seen[k] = get(seen, k, 0) + 1
                end
            end
        end
    end
end
println(n, " sources scanned; ", seen)
