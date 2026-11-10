# The uncompiled-instance report: instances of the system image that hold inferred code and no machine
# code, compiled in a session because a package image's code calls them without inlining (E-351 found
# `iterate(::Enumerate{Vector{Symbol}})` under TraitWorld's `_params_at`). A package image holds machine
# code only for the instances it stores; an instance the system image stores stays without, in every session.
# Input: a compile trace of a load (`--trace-compile=<log> --trace-compile-timing`). Each traced signature
# that evaluates in a session with no package loaded is looked up; it is listed where its instance has
# system-image code, inferred, never compiled.
#     julia-unified/julia --startup-file=no experiments/unification/audit/image_uncompiled.jl <trace.log> [n]
# A report: it asserts nothing.
const BOOT = Base.get_world_counter()
lines = readlines(ARGS[1])
top = length(ARGS) > 1 ? parse(Int, ARGS[2]) : 40
found = Tuple{Float64,String}[]
total = 0; other = 0; t_all = 0.0
for l in lines
    m = match(r"^#=\s*([0-9.]+) ms =# precompile\((.*)\)(\s*#.*)?$", l)
    m === nothing && continue
    global total += 1
    ms = parse(Float64, m.captures[1]); global t_all += ms
    tt = try
        Core.eval(Main, Meta.parse(m.captures[2]))
    catch
        nothing
    end
    (tt isa Type && tt <: Tuple) || (global other += 1; continue)
    mi = try
        Base.method_instance(Base.unwrap_unionall(tt).parameters[1].instance, Tuple{Base.unwrap_unionall(tt).parameters[2:end]...})
    catch
        nothing
    end
    (mi isa Core.MethodInstance && isdefined(mi, :cache)) || continue
    ci = mi.cache
    while true
        if ci.owner === nothing && ci.min_world <= BOOT && ci.max_world == typemax(UInt) &&
           ci.invoke == C_NULL && isdefined(ci, :inferred) && ci.inferred !== nothing
            push!(found, (ms, m.captures[2])); break
        end
        isdefined(ci, :next) || break
        ci = ci.next
    end
end
sort!(found; rev = true)
println("trace: ", ARGS[1])
println(total, " instances compiled, ", round(t_all; digits = 1), " ms; ", other, " at a package's types (not looked up)")
println(length(found), " with inferred code in the system image and no machine code, ", round(sum(first, found; init = 0.0); digits = 1), " ms:")
for (ms, s) in first(found, top)
    println("  ", lpad(ms, 7), " ms  ", first(s, 200))
end
