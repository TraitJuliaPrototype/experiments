# diagnosis: dynamic calls in the compiler methods the stack added (their cached specializations)
const CC = Base.Compiler
ranges = Dict{String,Vector{UnitRange{Int}}}()
for l in eachline(ARGS[1]); f, a, b = split(l); push!(get!(ranges, basename(f), UnitRange{Int}[]), parse(Int, a):parse(Int, b)); end
added(m::Method) = (rs = get(ranges, basename(string(m.file)), nothing); rs !== nothing && any(r -> m.line in r, rs))
ms = Method[]
for name in names(CC; all = true)
    isdefined(CC, name) || continue
    f = getfield(CC, name)
    (f isa Function || f isa Type) || continue
    for m in methods(f)
        m.module === CC && added(m) && push!(ms, m)
    end
end
println("stack-added compiler methods: ", length(unique(ms)))
report = Tuple{Int,String,Vector{String}}[]
for m in unique(ms)
    for mi in Base.specializations(m)
        mi === nothing && continue
        isdefined(mi, :cache) || continue
        local src
        try
            r = Base.code_typed_by_type(mi.specTypes; optimize = true)
            isempty(r) && continue
            src = r[1].first
        catch
            continue
        end
        calls = String[]
        for st in src.code
            if st isa Expr && st.head === :call
                g = st.args[1]
                gv = g isa GlobalRef ? (isdefined(g.mod, g.name) ? getfield(g.mod, g.name) : nothing) : g
                (gv isa Core.Builtin || gv isa Core.IntrinsicFunction) && continue
                gs = string(g)
                occursin("throw", gs) && continue
                push!(calls, first(gs, 60))
            end
        end
        isempty(calls) || push!(report, (length(calls), string(m.name, " @", basename(string(m.file)), ":", m.line, " ", first(string(mi.specTypes), 80)), unique(calls)[1:min(end, 6)]))
    end
end
sort!(report, by = x -> -x[1])
for (n, s, c) in report[1:min(end, 30)]; println(lpad(n, 4), "  ", s, "\n        ", join(c, ", ")); end
