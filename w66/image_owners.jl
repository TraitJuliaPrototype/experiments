# W-66 (the facts-first review §2.3, check (a)): after loading an environment's packages, the CodeInstances that
# came from package images, by owner: how many, and how many with machine code (an entry point set at load).
#     julia --project=<env> image_owners.jl Pkg1 Pkg2 ...
inimage(x) = ccall(:jl_object_in_image, Cint, (Any,), x) != 0
"Every CodeInstance cached in the method table now."
function allcis()
    out = Base.IdSet{Any}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
            ci = mi.cache
            while ci isa Core.CodeInstance
                push!(out, ci)
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    return out
end
const SYS = allcis()                           # the system image's, and this script's
for p in ARGS
    Base.require(Main, Symbol(p))
end
cnt = Dict{Any,Vector{Int}}()                 # owner => [from package images, with machine code]
ownername(o) = o === nothing ? "nothing" : o isa Symbol ? string(":", o) : string(typeof(o))
for ci in allcis()
    (ci in SYS || !inimage(ci)) && continue
    v = get!(() -> zeros(Int, 2), cnt, ownername(ci.owner))
    v[1] += 1
    getfield(ci, :invoke) != C_NULL && (v[2] += 1)
end
println("V julia ", Base.GIT_VERSION_INFO.commit_short, " packages ", join(ARGS, ","))
for (o, v) in sort!(collect(cnt); by = x -> -x[2][1])
    println("O ", rpad(o, 34), lpad(v[1], 8), " in images", lpad(v[2], 8), " with machine code")
end
