# W-143c: the statements of a culprit's code that carry its faults. For each culprit whose method name is
# ARGS[2] and whose signature's text contains ARGS[3] (optional): the code as plain inference types it
# (`code_typed` at the instance's signature, optimized), the lines that call a function of a fault.
#     CENSUS_WORK=table julia --project=envs/forks diag/code_of.jl <csv> Base.collect '_norm_eq##2'
include(joinpath(@__DIR__, "..", "census_lib.jl"))
const csv = ARGS[1]; const want = ARGS[2]; const sub = length(ARGS) >= 3 ? ARGS[3] : ""
S = census_session(csv)
done = Set{Any}()
for (y, k) in S.culprit
    mname(y) == want || continue
    t = y.def.specTypes; occursin(sub, string(t)) || continue
    t in done && continue; push!(done, t)
    println("== ", k, "  ", first(string(t), 200))
    short(g) = (u = string(g); m = match(r"^typeof\((.*)\)$", u); m !== nothing ? last(split(m[1], ".")) :
                (m2 = match(r"^Type\{(\w+)", u); m2 !== nothing ? m2[1] : u))
    fns = Set(short(fname(f.sig)) for f in S.fcache[y] if f.kind !== :mi)
    haskey(ENV, "KEYS") && union!(fns, split(ENV["KEYS"], ","))
    for f in S.fcache[y]; println("   fault ", f.kind, ": ", first(string(f.sig), 200)); end
    for (ci, rt) in Base.code_typed_by_type(t; optimize = get(ENV, "OPT", "1") == "1")
        for (i, st) in enumerate(ci.code)
            s = string(st)
            if any(fn -> occursin(fn, s), fns)
                println("   ", lpad(i, 4), "  ", first(s, 220), "  ::", first(string(ci.ssavaluetypes[i]), 60))
            end
        end
    end
end
