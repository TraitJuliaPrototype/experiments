# E-312: the facts code of a session's packages that fails G2, by reason (compiler §3.2): a dispatch edge
# not at a fact signature; an inlined callee whose cached CodeInstance fails G2; an inlined callee named by
# an edge to a CodeInstance outside its cache (no bit set) while the cached one satisfies G2.
#   SCRIPT=<script> julia --project=<env> g2_census.jl <Package> …
pkgs = Symbol.(ARGS)
for p in pkgs; @eval using $p; end
haskey(ENV, "SCRIPT") && (empty!(ARGS); include(ENV["SCRIPT"]))
const CC = Base.Compiler
mods = Set{Module}(getfield(Main, p) for p in pkgs)
inmods(m::Module) = m in mods || (parentmodule(m) !== m && inmods(parentmodule(m)))
incache(e) = (emi_ = CC.get_ci_mi(e); c = isdefined(emi_, :cache) ? emi_.cache : nothing; while c !== nothing; c === e && return true; c = isdefined(c, :next) ? c.next : nothing; end; false)
cachedg2(mi) = (c = isdefined(mi, :cache) ? mi.cache : nothing; while c !== nothing; (c.owner === nothing && c.max_world == typemax(UInt) && (getfield(c, :flags, :monotonic) & 0x10) != 0) && return true; c = isdefined(c, :next) ? c.next : nothing; end; false)
counts = Dict{String,Int}(); n = Ref(0); ng2 = Ref(0); ex = Dict{String,Vector{String}}()
mt = isdefined(Core, :methodtable) ? Core.methodtable : Core.GlobalMethods
Base.visit(mt) do m
    m isa Method && inmods(m.module) || return
    for mi in Base.specializations(m)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            fl = getfield(ci, :flags, :monotonic)::UInt8
            if ci.owner === nothing && ci.max_world == typemax(UInt) && (fl & 0x20) != 0
                n[] += 1
                if (fl & 0x10) != 0
                    ng2[] += 1
                else
                    reasons = Set{String}()
                    inl = isdefined(ci, :debuginfo) ? CC.inlined_defs!(Base.IdSet{Any}(), ci.debuginfo.edges) : Base.IdSet{Any}()
                    isdefined(ci, :debuginfo) || push!(reasons, "no debug info")
                    for e in ci.edges
                        e isa Core.CodeInstance || continue
                        emi = CC.get_ci_mi(e)
                        (emi in inl || emi.def in inl) || continue
                        (getfield(e, :flags, :monotonic) & 0x10) == 0 || continue
                        push!(reasons, incache(e) ? "inlined callee not G2" : cachedg2(emi) ? "inlined callee's edge names an uncached instance; the cached one is G2" : "inlined callee, uncached and not G2")
                    end
                    for (invokesig, item) in CC.ForwardToBackedgeIterator(ci.edges)
                        sig = item isa Core.MethodTable ? invokesig : item isa Core.MethodInstance && invokesig === nothing ? item.specTypes : nothing
                        sig === nothing || CC.is_fact_sig(sig) || push!(reasons, "a dispatch edge not at a fact signature")
                    end
                    isempty(reasons) && push!(reasons, "none found")
                    k = join(sort(collect(reasons)), " + ")
                    counts[k] = get(counts, k, 0) + 1
                    v = get!(() -> String[], ex, k); length(v) < 3 && push!(v, string(mi.specTypes)[1:min(end, 150)])
                end
            end
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
println("facts CodeInstances of ", join(pkgs, ", "), ": ", n[], "; G2 ", ng2[], "; not G2 ", n[] - ng2[])
for (k, c) in sort(collect(counts); by = x -> -x[2])
    println("  ", lpad(c, 6), "  ", k); for e in ex[k]; println("          ", e); end
end
