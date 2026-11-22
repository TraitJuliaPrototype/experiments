# W-169 (E-536): what the session compiled, read from the code instances themselves at its end.
# A code instance carries its own times (julia.h): `time_infer_self` (inference, set where it is inferred) and
# `time_compile` (code generation, added by the JIT; reset to 0 for every instance an image brings, staticdata.c).
# So at the session's end:
#   - every instance with time_compile > 0 had its machine code made in this process;
#   - an instance outside every image (`jl_object_in_image`: the system image's or a package image's memory) was
#     made, so inferred, in this process: its time_infer_self is this process's;
#   - an instance in an image with time_compile > 0: the image held its inferred code and no machine code (PE-32's
#     pattern), or its machine code was not usable;
#   - an instance whose MethodInstance also holds an ended instance (max_world < typemax) is compiled again.
# The census's own code: `census(devnull_path; label = "CENSUS0")` is called once before the session (prof.jl, at its
# start), so that its code is compiled there; what that first call sees is left out at the end (`exclude`).
# Writes one line per such instance (to the file W169_CENSUS names) and a summary to stdout:
#   CI <infer ms> <compile ms> <image|session> <again|first> <valid|ended> <facts> <specTypes>
const _FACTS = 0x20
h2f(x::UInt16) = Float64(reinterpret(Float16, x))
h2f(x::Real) = Float64(x)
function census(path; exclude = nothing, label = "CENSUS")
    seen = IdSet{Core.CodeInstance}()
    n = 0; tinf = 0.0; tgen = 0.0
    sums = Dict{String,Vector{Float64}}()
    open(path, "w") do io
        Base.visit(Core.methodtable) do m
            for mi in Base.specializations(m)
                mi isa Core.MethodInstance || continue
                isdefined(mi, :cache) || continue
                cis = Core.CodeInstance[]
                ci = mi.cache
                while true
                    ci.owner === nothing && push!(cis, ci)
                    isdefined(ci, :next) || break
                    ci = ci.next
                end
                ended = any(c -> c.max_world != typemax(UInt), cis)
                for c in cis
                    fl = getfield(c, :flags, :monotonic)::UInt8
                    img = ccall(:jl_object_in_image, UInt8, (Any,), c) != 0
                    gen = h2f(getfield(c, :time_compile, :monotonic)) * 1000
                    inf = img ? 0.0 : h2f(c.time_infer_self) * 1000
                    (gen > 0 || (!img && inf > 0)) || continue
                    push!(seen, c)
                    exclude === nothing || !(c in exclude) || continue
                    valid = c.max_world == typemax(UInt)
                    again = ended && valid
                    key = string(img ? "image" : "session", " ", again ? "again" : "first", " ", (fl & _FACTS) != 0 ? "facts" : "plain")
                    s = get!(() -> zeros(3), sums, key); s[1] += 1; s[2] += inf; s[3] += gen
                    n += 1; tinf += inf; tgen += gen
                    st = try replace(sprint(show, mi.specTypes; context = :module => Core), '\n' => ' ', '\t' => ' ') catch; "?" end
                    println(io, "CI\t", round(inf; digits = 2), "\t", round(gen; digits = 2), "\t", img ? "image" : "session", "\t",
                            again ? "again" : "first", "\t", valid ? "valid" : "ended", "\t", (fl & _FACTS) != 0 ? "facts" : "plain", "\t", st)
                end
            end
        end
    end
    println(label, " instances compiled or inferred in this process ", n, " | inference (self) ", round(tinf; digits = 1),
            " ms | code generation ", round(tgen; digits = 1), " ms")
    for (k, s) in sort(collect(sums); by = x -> -(x[2][2] + x[2][3]))
        println(label, " ", k, ": ", Int(s[1]), " instances, inference ", round(s[2]; digits = 1), " ms, code generation ", round(s[3]; digits = 1), " ms")
    end
    return seen
end
