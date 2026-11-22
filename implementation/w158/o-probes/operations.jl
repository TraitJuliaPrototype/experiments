# W-158 (traits T-162): every trait a demonstrator's module declares, and each of its operations whose function is the
# module's own: exported, public, declared `@owner_only`, owner-only to the compiler (`Compiler.is_owner_only`), and the
# methods of the function by module. Run with a project that holds the demonstrators:
#     julia --project=<env> operations.jl [Package ...]        (default: the trait packages of env_demo_g)
using TraitWorld
pkgs = isempty(ARGS) ? ["TraitTables", "TraitCSV", "TraitMakie", "TraitDifferentialEquations"] : ARGS
for p in pkgs
    Core.eval(Main, :(using $(Symbol(p))))
end
const CC = Core.Compiler
println("TraitWorld ", pathof(TraitWorld))
mods = Module[]
function walk!(M::Module)
    M in mods && return
    push!(mods, M)
    for n in names(M; all = true)
        isdefined(M, n) || continue
        v = try getglobal(M, n) catch; continue end
        v isa Module && parentmodule(v) === M && v !== M && walk!(v)
    end
end
for M in Base.loaded_modules_array()
    walk!(M)
end
oo(M) = (ccall(:jl_get_module_trait_options, Cint, (Any,), M) & 64) != 0
rows = Any[]
for M in mods
    for n in names(M; all = true)
        isdefined(M, n) || continue
        X = try getglobal(M, n) catch; continue end
        X isa Type || continue
        TraitWorld.istrait(Base.unwrap_unionall(X)) || continue
        c = TraitWorld.contract(X)
        (c === nothing || c.mod !== M || TraitWorld.bare(c.trait) !== X) && continue
        for op in c.operations
            f = op.f
            f isa Function || continue
            F = typeof(f)
            fm = parentmodule(f)
            fm === M || isdefined(F.name, :singletonname) && F.name.module === M || continue
            nm = nameof(f)
            exported = Base.isexported(fm, nm)
            public = Base.ispublic(fm, nm)
            flag = ccall(:jl_binding_owner_only_p, Cint, (Any, Any), fm, nm) != 0
            ms = methods(f)
            others = sort!(unique([string(Base.moduleroot(m.module)) for m in ms if Base.moduleroot(m.module) !== Base.moduleroot(fm)]))
            push!(rows, (string(M), string(n), string(nm), oo(fm), exported, public, flag, CC.is_owner_only(F), length(ms), join(others, " ")))
        end
    end
end
println("module\ttrait\toperation\tmodule owner_only\texported\tpublic\t@owner_only\towner-only (compiler)\tmethods\tmethods from other packages")
for r in rows
    println(join(r, "\t"))
end
n_oo = count(r -> r[8], rows)
println("# operations ", length(rows), "; owner-only to the compiler ", n_oo, "; of those with methods from other packages ", count(r -> r[8] && !isempty(r[10]), rows))
