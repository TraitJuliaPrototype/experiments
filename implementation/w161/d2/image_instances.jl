# W-161, E-501 (open issue 228): the instances with valid code that the package images hold right after loading,
# for every method of the named packages (loaded directly or as dependencies of the first): one line per instance,
# sorted, so that two builds' lists can be compared with `diff`.
#     julia --project=<env> image_instances.jl <out file> <package to load> <package>...
out = ARGS[1]
Core.eval(Main, Meta.parse("using TraitWorld, $(ARGS[2])"))
pkgs = ARGS[2:end]
roots = Set{Module}(m for m in values(Base.loaded_modules) if string(nameof(m)) in pkgs)
inpkg(m::Module) = Base.moduleroot(m) in roots || any(r -> parentmodule(m) === r, roots)
lines = String[]
Base.visit(Core.methodtable) do m
    inpkg(m.module) || return
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            if ci.max_world == typemax(UInt)
                push!(lines, string(nameof(Base.moduleroot(m.module)), "\t", mi.specTypes))
                break
            end
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
sort!(lines)
open(out, "w") do io
    foreach(l -> println(io, l), lines)
end
println(length(lines), " instances with valid code in ", join(pkgs, ", "), " -> ", out)
