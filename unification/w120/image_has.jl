# W-120: does an image hold a method's instances, and are they valid after the load? After loading the
# packages, each CodeInstance of the named functions: its world range, and its flags (compiled by facts,
# from an image, with native code, the G2 bit).
#     julia --project=<env> image_has.jl <package> <Module.function> [<Module.function> ...]
pkg = Symbol(popfirst!(ARGS))
@eval using $pkg
root = getglobal(Main, pkg)
function resolve(path::String)
    parts = Symbol.(split(path, "."))
    m = only(x for x in values(Base.loaded_modules) if nameof(x) === parts[1])
    for p in parts[2:end-1]; m = getglobal(m, p); end
    return getglobal(m, parts[end])
end
for path in ARGS
    f = resolve(path)
    n = 0
    for m in methods(f), mi in Base.specializations(m)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            fl = getfield(ci, :flags, :monotonic)::UInt8
            n += 1
            println(path, " | ", first(string(mi.specTypes), 150), "\n      owner=", ci.owner === nothing ? "-" : string(ci.owner),
                    " world=", Int(ci.min_world), ":", ci.max_world == typemax(UInt) ? "∞" : string(Int(ci.max_world)),
                    " facts=", (fl & 0x20) != 0, " G2=", (fl & 0x10) != 0, " image=", (fl & 0x04) != 0,
                    " native=", (fl & 0x08) != 0, " invoke=", ci.invoke != C_NULL, " inferred=", isdefined(ci, :inferred) && ci.inferred !== nothing)
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
    println(path, ": ", n, " code instances; the session's world is ", Int(Base.get_world_counter()))
end
