# U6 (E-252): a fresh session in an arrangement's environment (run with --project=arr/<R>/env).
#
#     julia session.jl <R> <step1,step2,...>
#
# Loads packages step by step (`using <step>`); the step `main` compiles `h() = Fo.f(Sp.Ty())` in Main
# and calls it (the row's case (3)). After each step it prints, for every probing module that exists:
#   seen      what `g()` returned when the module's body ran (in precompilation: in the child that wrote its image)
#   loaded    which of the arrangement's modules were loaded at that moment
#   image     whether the body ran while writing an image (true) or in this session (false)
#   now       what `g()` answers now
# and the invalidations logged during the step, by tag (src/gf.c, Compiler/src/reinfer.jl).
using TOML
const R = ARGS[1]
const STEPS = split(ARGS[2], ",")
const META = TOML.parsefile(joinpath(@__DIR__, "arr", R, "meta.toml"))
const OURS = Set(vcat(META["pkgs"], META["exts"]))

const RU = Base.Compiler.ReinferUtils
loaded_ours() = filter(in(OURS), [String(nameof(m)) for m in Base.loaded_modules_order])

function probe_module(spec)
    if startswith(spec, "ext:")
        _, parent, ext = String.(split(spec, ":"))
        id = Base.identify_package(parent)
        haskey(Base.loaded_modules, id) || return nothing
        return Base.get_extension(Base.loaded_modules[id], Symbol(ext))
    end
    id = Base.identify_package(spec)
    id === nothing && return nothing
    return get(Base.loaded_modules, id, nothing)
end

function tags(list)
    c = Dict{String,Int}()
    for x in list
        x isa String && (c[x] = get(c, x, 0) + 1)
        x isa Core.MethodInstance && (c["MethodInstance"] = get(c, "MethodInstance", 0) + 1)
        x isa Core.CodeInstance && (c["CodeInstance"] = get(c, "CodeInstance", 0) + 1)
    end
    return c
end

println("RESULT $R steps=$(join(STEPS, ",")) julia=$(Base.GIT_VERSION_INFO.commit_short) compiled_modules=$(Base.JLOptions().use_compiled_modules)")
for step in STEPS
    pre = Dict(p => (id = Base.identify_package(p); id === nothing ? nothing : Base.isprecompiled(id)) for p in META["pkgs"])
    log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
    RU.debug_method_invalidation(true)   # load-time verification of images (Compiler/src/reinfer.jl)
    if step == "main"
        Core.eval(Main, :(import Fo, Sp; h() = Fo.f(Sp.Ty()); const HMAIN = h()))
    else
        Core.eval(Main, :(using $(Symbol(step))))
    end
    ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
    loadlog = RU._jl_debug_method_invalidation[]; RU.debug_method_invalidation(false)
    println("RESULT $R step=$step isprecompiled_before=", join(["$k=$v" for (k, v) in sort(collect(pre)) if v !== nothing], " "))
    println("RESULT $R step=$step loaded_now=", join(loaded_ours(), ">"))
    println("RESULT $R step=$step invalidation_tags=", tags(log), " load_tags=", tags(loadlog))
    for x in vcat(log, something(loadlog, Any[]))
        x isa Core.MethodInstance && println("RESULT $R step=$step   invalidated: ", x)
    end
    if step == "main"
        println("RESULT $R step=main h_at_compile=", Main.HMAIN)
    end
    if isdefined(Main, :h)
        println("RESULT $R step=$step main_h_now=", Base.invokelatest(Main.h))
    end
    for (name, spec) in sort(collect(META["probes"]))
        m = probe_module(spec)
        m === nothing && continue
        println("RESULT $R step=$step probe=$name seen=$(m.SEEN) loaded=$(join(m.AT_COMPILE, ">")) image=$(m.GENERATING) now=$(Base.invokelatest(m.g))")
    end
end
