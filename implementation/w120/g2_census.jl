# W-120: the pattern of E-372, as a census. After a program's session, every valid instance of the
# trait packages' methods under Julia's own owner: how many satisfy G2 (compiler §3.2), and for those
# that do not, the edges at the end of each failing chain, counted. An edge that is no fact keeps an
# instance out of every image.
#     julia --project=<env> g2_census.jl <script.jl> <RootModule> [<RootModule> ...] [-- args…]
script = abspath(popfirst!(ARGS))
i = findfirst(==("--"), ARGS)
roots = Symbol.(i === nothing ? ARGS : ARGS[1:i-1])
sargs = i === nothing ? String[] : ARGS[i+1:end]
include(script)
redirect_stdout(devnull) do; Base.invokelatest(main, sargs); end
const CC = Base.Compiler
g2(ci) = (getfield(ci, :flags, :monotonic)::UInt8 & 0x10) != 0
function leaves!(out, ci::Core.CodeInstance, seen, depth = 0)
    ci in seen && return
    push!(seen, ci)
    (isdefined(ci, :debuginfo) && isdefined(ci, :edges)) || return      # (an image's instance without its record)
    inl = CC.inlined_defs!(Base.IdSet{Any}(), ci.debuginfo.edges)
    for e in ci.edges
        e isa Core.CodeInstance || continue
        mi = CC.get_ci_mi(e)
        (mi in inl || mi.def in inl) || continue
        g2(e) || (depth < 8 && leaves!(out, e, seen, depth + 1))
    end
    for (invokesig, item) in CC.ForwardToBackedgeIterator(ci.edges)
        if item isa Core.MethodTable
            CC.is_fact_sig(invokesig) || push!(out, "at a table: " * first(string(invokesig), 150))
        elseif item isa Core.MethodInstance
            invokesig === nothing || continue
            CC.is_fact_sig(item.specTypes) || push!(out, "at an instance: " * first(string(item.specTypes), 150))
        end
    end
end
function allmodules!(out, m::Module)
    m in out && return
    push!(out, m)
    for n in names(m; all = true)
        isdefined(m, n) || continue
        v = getglobal(m, n)
        v isa Module && parentmodule(v) === m && v !== m && allmodules!(out, v)
    end
end
total = 0; good = 0; causes = Dict{String,Int}(); bymod = Dict{Any,Tuple{Int,Int}}(); nocause = 0
mods = Module[]
for r in roots
    allmodules!(mods, only(x for x in values(Base.loaded_modules) if nameof(x) === r))
end
seenm = Base.IdSet{Method}()
for m in mods, n in names(m; all = true)
    isdefined(m, n) || continue
    f = getglobal(m, n)
    (f isa Function || f isa Type) || continue
    for meth in methods(f)
        (meth.module in mods && !(meth in seenm)) || continue
        push!(seenm, meth)
        for mi in Base.specializations(meth)
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci !== nothing
                if ci.owner === nothing && ci.max_world == typemax(UInt)
                    global total += 1
                    r = Base.moduleroot(meth.module)
                    t, g = get(bymod, r, (0, 0))
                    if g2(ci)
                        global good += 1; bymod[r] = (t + 1, g + 1)
                    else
                        bymod[r] = (t + 1, g)
                        out = String[]
                        leaves!(out, ci, Base.IdSet{Any}())
                        isempty(out) && (global nocause += 1)
                        for c in unique(out); causes[c] = get(causes, c, 0) + 1; end
                    end
                end
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
end
println(total, " valid instances of ", join(roots, ", "), "; ", good, " satisfy G2 (", round(100 * good / max(total, 1); digits = 1), " %), ", total - good, " do not")
for (r, (t, g)) in sort!(collect(bymod); by = x -> -(x[2][1] - x[2][2])); println("  ", r, ": ", t - g, " of ", t, " fail"); end
println("the edges at the end of the failing chains, by the instances they keep out (", nocause, " failing instances show none):")
for (c, n) in first(sort!(collect(causes); by = last, rev = true), 25); println(lpad(n, 6), "  ", c); end
